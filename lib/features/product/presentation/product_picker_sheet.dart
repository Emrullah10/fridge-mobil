import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/product_providers.dart';
import '../data/product_repository.dart';

const _units = ['piece', 'gram', 'kilogram', 'milliliter', 'liter', 'package'];
const _unitLabels = {
  'piece': 'Adet',
  'gram': 'Gram',
  'kilogram': 'Kilogram',
  'milliliter': 'Mililitre',
  'liter': 'Litre',
  'package': 'Paket',
};

/// Ürün arama/seçme/oluşturma bottom sheet'i. Fiş düzeltme ve manuel
/// envanter ekleme ekranlarının ikisi de bunu kullanır — tek bir yerden
/// ürün seçtirme mantığı, tutarlı davranış.
Future<Product?> showProductPicker(BuildContext context, {required String householdId}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ProductPickerSheet(householdId: householdId),
  );
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet({required this.householdId});
  final String householdId;

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  final _searchController = TextEditingController();
  List<Product> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await ref.read(productRepositoryProvider).search(widget.householdId, query: query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _createNew() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    String selectedUnit = 'piece';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('"$query" ürününü oluştur'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedUnit,
            decoration: const InputDecoration(labelText: 'Birim'),
            items: [for (final u in _units) DropdownMenuItem(value: u, child: Text(_unitLabels[u]!))],
            onChanged: (value) => setDialogState(() => selectedUnit = value ?? 'piece'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Oluştur')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final product = await ref
        .read(productRepositoryProvider)
        .create(widget.householdId, canonicalName: query, defaultUnit: selectedUnit);
    if (mounted) Navigator.of(context).pop(product);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Ürün ara',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  for (final product in _results)
                    ListTile(
                      title: Text(product.canonicalName),
                      subtitle: Text(_unitLabels[product.defaultUnit] ?? product.defaultUnit),
                      onTap: () => Navigator.of(context).pop(product),
                    ),
                  if (_searchController.text.trim().isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline_rounded),
                      title: Text('"${_searchController.text.trim()}" olarak yeni ürün ekle'),
                      onTap: _createNew,
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
