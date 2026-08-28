import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/button_progress.dart';
import '../../../core/widgets/form_error_text.dart';
import '../../../core/widgets/responsive.dart';
import '../../product/application/product_providers.dart';
import '../../product/data/product_repository.dart';
import '../../product/presentation/product_picker_sheet.dart';
import '../application/inventory_providers.dart';
import 'barcode_scan_screen.dart';

class AddInventoryItemScreen extends ConsumerStatefulWidget {
  const AddInventoryItemScreen({super.key, required this.householdId, required this.storageLocationId});

  final String householdId;
  final String storageLocationId;

  @override
  ConsumerState<AddInventoryItemScreen> createState() => _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState extends ConsumerState<AddInventoryItemScreen> {
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  Product? _selectedProduct;
  DateTime? _expiresAt;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final product = await showProductPicker(context, householdId: widget.householdId);
    if (product != null) setState(() => _selectedProduct = product);
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code == null || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final result = await ref.read(productRepositoryProvider).lookupBarcode(widget.householdId, code);
      if (!mounted) return;
      if (result.found && result.product != null) {
        setState(() => _selectedProduct = result.product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.product!.canonicalName} seçildi')),
        );
      } else {
        setState(() => _errorMessage = 'Barkod tanınmadı ($code). Ürünü elle seçebilirsin.');
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = describeApiError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

    final priceText = _unitPriceController.text.trim().replaceAll(',', '.');
    final unitPrice = priceText.isEmpty ? null : double.tryParse(priceText);

    try {
      await ref.read(inventoryRepositoryProvider).addItem(
            widget.householdId,
            storageLocationId: widget.storageLocationId,
            productId: product.id,
            unit: product.defaultUnit,
            quantity: quantity,
            expiresAt: _expiresAt,
            unitPrice: unitPrice,
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

    return Scaffold(
      appBar: AppBar(title: const Text('Dolaba Ekle')),
      // Klavye açıldığında TextField taşmasın diye SafeArea + scroll view
      // içine alınır (önceden Column doğrudan Padding altındaydı ve
      // klavye açılınca RenderFlex overflow veriyordu).
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: formMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.search_rounded),
                          label: Text(
                            _selectedProduct?.canonicalName ?? 'Ürün seç',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: _isSaving ? null : _pickProduct,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.outlined(
                        tooltip: 'Barkod okut',
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        onPressed: _isSaving ? null : _scanBarcode,
                      ),
                    ],
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
                  TextField(
                    controller: _unitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Birim fiyat (opsiyonel)',
                      prefixText: '₺ ',
                      helperText: 'Para & israf panelinde harcamayı görebilmek için',
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
                    FormErrorText(_errorMessage!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving ? const ButtonProgress() : const Text('Ekle'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
