import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_action_sheet.dart';
import '../../../core/ui/app_progress.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/widgets/unit_label.dart';
import '../application/product_providers.dart';
import '../data/product_repository.dart';

const _units = unitOptions;

/// Ürün arama/seçme/oluşturma bottom sheet'i. Fiş düzeltme ve manuel
/// envanter ekleme ekranlarının ikisi de bunu kullanır — tek bir yerden
/// ürün seçtirme mantığı, tutarlı davranış.
///
/// `draggable: true` ile açılır — kullanıcı gerçek cihazda "biraz daha
/// yukarı kayabilir, daha yüksek olmalı" dedi; artık %85 açılıp %92'ye
/// kadar sürüklenebiliyor (eskiden %70/%90). Tutamaç + ✕ artık
/// `showAppSheet`/`AppSheetScaffold`'un ortak kabuğundan geliyor — eskiden
/// bu sheet kendi `DraggableScrollableSheet`'ini kurduğu için global
/// tutamacı kapatmak zorundaydı, o istisna kalktı.
Future<Product?> showProductPicker(
  BuildContext context, {
  required String householdId,
}) {
  return showAppSheet<Product>(
    context,
    draggable: true,
    builder: (_, scrollController) => _ProductPickerSheet(
      householdId: householdId,
      scrollController: scrollController,
    ),
  );
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet({required this.householdId, this.scrollController});
  final String householdId;
  final ScrollController? scrollController;

  @override
  ConsumerState<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
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
      final results = await ref
          .read(productRepositoryProvider)
          .search(widget.householdId, query: query);
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

    // Eskiden "birim seç" ayrı bir onay dialoguydu (Dropdown + İptal/Oluştur)
    // — nested modal (sheet üstünde dialog) ve gereksiz bir ekstra adımdı.
    // Action sheet ile tek dokunuşta hem seçim hem onay.
    final selectedUnit = await showAppActionSheet<String>(
      context,
      title: '"$query" ürününü oluştur',
      message: 'Birim seç',
      actions: [
        for (final u in _units) AppSheetAction(value: u, label: unitLabel(u)),
      ],
    );
    if (selectedUnit == null || !mounted) return;

    final product = await ref
        .read(productRepositoryProvider)
        .create(
          widget.householdId,
          canonicalName: query,
          defaultUnit: selectedUnit,
        );
    if (mounted) Navigator.of(context).pop(product);
  }

  @override
  Widget build(BuildContext context) {
    // AppSheetScaffold'un varsayılan SingleChildScrollView'ı kullanılmıyor
    // — liste kendi ölçülü ScrollController'ıyla (DraggableScrollableSheet
    // tarafından sağlanan) akmalı. Bu yüzden başlık barını doğrudan
    // AppSheetScaffold'dan, gövdeyi Expanded bir Column'dan kuruyoruz.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          AppSheetScaffold(
            onClose: () => Navigator.of(context).pop(),
            title: 'Ürün ara',
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (_, value, _) => AppTextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: _onQueryChanged,
                decoration: InputDecoration(
                  labelText: 'Ürün ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Temizle',
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                        ),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: AppProgress(size: 20, strokeWidth: 2),
            ),
          Expanded(
            child:
                _results.isEmpty &&
                    !_isLoading &&
                    _searchController.text.trim().isEmpty
                ? const Center(child: _EmptySearchHint())
                : ListView(
                    controller: widget.scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    children: [
                      for (final product in _results)
                        ListTile(
                          title: Text(product.canonicalName),
                          subtitle: Text(unitLabel(product.defaultUnit)),
                          onTap: () => Navigator.of(context).pop(product),
                        ),
                      if (_searchController.text.trim().isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.add_circle_outline_rounded),
                          title: Text(
                            '"${_searchController.text.trim()}" olarak yeni ürün ekle',
                          ),
                          onTap: _createNew,
                        ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptySearchHint extends StatelessWidget {
  const _EmptySearchHint();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Aramaya başla',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
