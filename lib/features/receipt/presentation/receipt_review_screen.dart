import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../household/application/household_providers.dart';
import '../../product/presentation/product_picker_sheet.dart';
import '../application/receipt_providers.dart';
import '../data/receipt_repository.dart';

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.householdId,
    required this.scanId,
    required this.lineItems,
  });

  final String householdId;
  final String scanId;
  final List<ReceiptLineItem> lineItems;

  @override
  ConsumerState<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  late final List<ReceiptLineItem> _items = List.of(widget.lineItems);
  // Eşleşmemiş satırlar hiçbir zaman kalmıyor (AI otomatik ürün oluşturuyor),
  // ama düşük güvenli satırları varsayılan seçili göndermek riskli — kullanıcı
  // önce göz atmalı. Sadece yüksek güvenli (alias/trigram) satırlar baştan seçili.
  late final Set<String> _selectedIds =
      _items.where((i) => i.isHighConfidence).map((i) => i.id).toSet();
  final Map<String, DateTime?> _expiresAtByItemId = {};
  String? _selectedLocationId;
  bool _isConfirming = false;

  Future<void> _editItem(ReceiptLineItem item) async {
    final nameController = TextEditingController(text: item.parsedName);
    final quantityController = TextEditingController(text: item.parsedQuantity.toString());
    String selectedProductId = item.matchedProductId!;
    String selectedProductName = item.parsedName;

    final edited = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Satırı Düzelt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Fişte yazan: "${item.rawText}"', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.search_rounded),
                label: Text(selectedProductName),
                onPressed: () async {
                  final picked = await showProductPicker(context, householdId: widget.householdId);
                  if (picked != null) {
                    setDialogState(() {
                      selectedProductId = picked.id;
                      selectedProductName = picked.canonicalName;
                      nameController.text = picked.canonicalName;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Ürün adı')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Miktar'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );

    if (edited != true || !mounted) return;

    final newName = nameController.text.trim();
    final newQuantity = double.tryParse(quantityController.text) ?? item.parsedQuantity;

    try {
      await ref.read(receiptRepositoryProvider).correctLineItem(
            widget.householdId,
            widget.scanId,
            item.id,
            parsedName: newName,
            parsedQuantity: newQuantity,
            parsedUnit: item.parsedUnit,
            matchedProductId: selectedProductId,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
      return; // Sunucu güncellemesi başarısızsa lokal state'i değiştirme.
    }

    setState(() {
      final index = _items.indexWhere((i) => i.id == item.id);
      _items[index] = ReceiptLineItem(
        id: item.id,
        rawText: item.rawText,
        parsedName: newName,
        parsedQuantity: newQuantity,
        parsedUnit: item.parsedUnit,
        matchedProductId: selectedProductId,
        matchMethod: 'manual',
        confidence: 1.0,
      );
      _selectedIds.add(item.id); // Kullanıcı düzelttiyse artık güveniyoruz demektir.
    });
  }

  Future<void> _pickExpiryDate(String itemId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _expiresAtByItemId[itemId] = picked);
  }

  Future<void> _confirm() async {
    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir dolap/bölüm seç')),
      );
      return;
    }

    final selectedItems = _items.where((i) => _selectedIds.contains(i.id)).toList();

    setState(() => _isConfirming = true);
    try {
      await ref.read(receiptRepositoryProvider).confirm(
            widget.householdId,
            widget.scanId,
            storageLocationId: _selectedLocationId!,
            items: selectedItems,
            expiresAtByItemId: _expiresAtByItemId,
          );
      if (mounted) {
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(storageLocationsProvider(widget.householdId));
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Fişi Onayla')),
      body: Column(
        children: [
          locationsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (locations) {
              _selectedLocationId ??= locations.isNotEmpty ? locations.first.id : null;
              return Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedLocationId,
                  decoration: const InputDecoration(
                    labelText: 'Nereye eklensin?',
                    prefixIcon: Icon(Icons.kitchen_rounded),
                  ),
                  items: [
                    for (final location in locations)
                      DropdownMenuItem(value: location.id, child: Text(location.name)),
                  ],
                  onChanged: (value) => setState(() => _selectedLocationId = value),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              children: [
                Text(
                  '${_items.length} ürün bulundu',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${_selectedIds.length} seçili',
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = _selectedIds.contains(item.id);
                final expiresAt = _expiresAtByItemId[item.id];
                return Card(
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _selectedIds.add(item.id);
                          } else {
                            _selectedIds.remove(item.id);
                          }
                        }),
                        title: Text(item.parsedName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text('${item.parsedQuantity} ${item.parsedUnit}'),
                              if (!item.isHighConfidence)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Kontrol et',
                                    style: TextStyle(fontSize: 11, color: colorScheme.onErrorContainer),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Düzelt',
                          onPressed: () => _editItem(item),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: const Icon(Icons.event_rounded, size: 16),
                            label: Text(
                              expiresAt != null
                                  ? 'SKT: ${dateFormat.format(expiresAt)}'
                                  : 'Son kullanma tarihi ekle (opsiyonel)',
                            ),
                            onPressed: () => _pickExpiryDate(item.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            onPressed: _isConfirming || _selectedIds.isEmpty ? null : _confirm,
            child: _isConfirming
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('${_selectedIds.length} ürünü dolaba ekle'),
          ),
        ),
      ),
    );
  }
}
