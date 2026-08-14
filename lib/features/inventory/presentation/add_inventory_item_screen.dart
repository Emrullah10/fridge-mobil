import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../product/data/product_repository.dart';
import '../../product/presentation/product_picker_sheet.dart';
import '../application/inventory_providers.dart';

class AddInventoryItemScreen extends ConsumerStatefulWidget {
  const AddInventoryItemScreen({super.key, required this.householdId, required this.storageLocationId});

  final String householdId;
  final String storageLocationId;

  @override
  ConsumerState<AddInventoryItemScreen> createState() => _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState extends ConsumerState<AddInventoryItemScreen> {
  final _quantityController = TextEditingController(text: '1');
  Product? _selectedProduct;
  DateTime? _expiresAt;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final product = await showProductPicker(context, householdId: widget.householdId);
    if (product != null) setState(() => _selectedProduct = product);
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _save() async {
    final product = _selectedProduct;
    if (product == null) {
      setState(() => _errorMessage = 'Önce bir ürün seç');
      return;
    }
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      setState(() => _errorMessage = 'Geçerli bir miktar gir');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref.read(inventoryRepositoryProvider).addItem(
            widget.householdId,
            storageLocationId: widget.storageLocationId,
            productId: product.id,
            unit: product.defaultUnit,
            quantity: quantity,
            expiresAt: _expiresAt,
          );
      final params = InventoryParams(householdId: widget.householdId, storageLocationId: widget.storageLocationId);
      ref.invalidate(inventoryItemsProvider(params));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _errorMessage = describeApiError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Dolaba Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.search_rounded),
              label: Text(_selectedProduct?.canonicalName ?? 'Ürün seç'),
              onPressed: _pickProduct,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Miktar',
                suffixText: _selectedProduct?.defaultUnit,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_rounded),
              label: Text(
                _expiresAt != null
                    ? 'SKT: ${dateFormat.format(_expiresAt!)}'
                    : 'Son kullanma tarihi ekle (opsiyonel)',
              ),
              onPressed: _pickExpiryDate,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_errorMessage!, style: TextStyle(color: colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
