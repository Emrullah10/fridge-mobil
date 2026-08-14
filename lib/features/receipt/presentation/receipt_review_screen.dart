import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../household/application/household_providers.dart';
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
  late final Set<String> _selectedIds = _items.map((i) => i.id).toSet();
  String? _selectedLocationId;
  bool _isConfirming = false;

  Future<void> _editItem(ReceiptLineItem item) async {
    final nameController = TextEditingController(text: item.parsedName);
    final quantityController = TextEditingController(text: item.parsedQuantity.toString());

    final edited = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Satırı Düzelt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Fişte yazan: "${item.rawText}"', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Ürün adı')),
            const SizedBox(height: 12),
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
    );

    if (edited != true) return;

    final newName = nameController.text.trim();
    final newQuantity = double.tryParse(quantityController.text) ?? item.parsedQuantity;

    await ref.read(receiptRepositoryProvider).correctLineItem(
          widget.householdId,
          widget.scanId,
          item.id,
          parsedName: newName,
          parsedQuantity: newQuantity,
          parsedUnit: item.parsedUnit,
        );

    setState(() {
      final index = _items.indexWhere((i) => i.id == item.id);
      _items[index] = ReceiptLineItem(
        id: item.id,
        rawText: item.rawText,
        parsedName: newName,
        parsedQuantity: newQuantity,
        parsedUnit: item.parsedUnit,
        matchedProductId: item.matchedProductId,
        matchMethod: 'manual',
        confidence: 1.0,
      );
    });
  }

  Future<void> _confirm() async {
    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir dolap/bölüm seç')),
      );
      return;
    }

    setState(() => _isConfirming = true);
    try {
      await ref.read(receiptRepositoryProvider).confirm(
            widget.householdId,
            widget.scanId,
            storageLocationId: _selectedLocationId!,
            lineItemIds: _selectedIds.toList(),
          );
      if (mounted) {
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Onaylanamadı: $error')));
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(storageLocationsProvider(widget.householdId));
    final colorScheme = Theme.of(context).colorScheme;

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
                return Card(
                  child: CheckboxListTile(
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
