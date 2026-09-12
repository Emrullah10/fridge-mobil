import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_number_field.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/form_error_text.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/unit_label.dart';
import '../../household/data/household_repository.dart';
import '../../product/data/product_repository.dart';
import '../../product/presentation/product_picker_sheet.dart';
import '../data/receipt_repository.dart' show ReceiptLineItem;

/// [ReceiptLineEditScreen]'in döndürdüğü düzenlenmiş değerler. Sunucu
/// çağrısı (correctLineItem) ve lokal state güncellemesi ÇAĞIRAN TARAFTA
/// kalır — bu ekranın tek işi kullanıcıdan yeni değerleri toplamak.
class ReceiptLineEdit {
  const ReceiptLineEdit({
    required this.locationId,
    required this.productId,
    required this.name,
    required this.brand,
    required this.quantity,
    required this.unit,
    required this.packSize,
    required this.packUnit,
    required this.price,
    required this.categoryKey,
  });

  final String? locationId;
  final String productId;
  final String name;
  final String? brand;
  final double quantity;
  final String unit;
  final double? packSize;
  final String? packUnit;
  final double? price;
  final String? categoryKey;
}

/// "Satırı Düzelt" — eskiden 8 alan (bölüm/ürün/ad/marka/miktar/birim/
/// paket/fiyat/kategori) + nested ürün seçici bir `AlertDialog`'a
/// sıkıştırılıyordu. Tam ekrana taşındı: klavye + nested sheet birlikte artık
/// çakışmıyor, iOS'ta swipe-back bedava geliyor, `AppFormScroll` kullanılıyor
/// (Center DEĞİL — form ekranı üstten başlamalı).
class ReceiptLineEditScreen extends StatefulWidget {
  const ReceiptLineEditScreen({
    super.key,
    required this.householdId,
    required this.item,
    required this.locations,
    required this.categories,
    required this.initialLocationId,
  });

  final String householdId;
  final ReceiptLineItem item;
  final List<StorageLocation> locations;
  final List<ProductCategory> categories;
  final String? initialLocationId;

  @override
  State<ReceiptLineEditScreen> createState() => _ReceiptLineEditScreenState();
}

class _ReceiptLineEditScreenState extends State<ReceiptLineEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _quantityController;
  late final TextEditingController _packSizeController;
  late final TextEditingController _priceController;
  final _brandFocus = FocusNode();
  final _quantityFocus = FocusNode();
  final _packSizeFocus = FocusNode();
  final _priceFocus = FocusNode();

  late String _selectedProductId;
  late String _selectedProductName;
  String? _selectedLocationId;
  late String _selectedUnit;
  String? _selectedCategoryKey;
  late String _selectedPackUnit;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item.parsedName);
    _brandController = TextEditingController(text: item.parsedBrand ?? '');
    _quantityController = TextEditingController(
      text: item.parsedQuantity.toString(),
    );
    _packSizeController = TextEditingController(
      text: item.parsedPackSize?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: item.parsedPrice?.toString() ?? '',
    );
    _selectedProductId = item.matchedProductId!;
    _selectedProductName = item.parsedName;
    _selectedLocationId = widget.initialLocationId;
    _selectedUnit = item.parsedUnit;
    _selectedPackUnit = item.parsedPackUnit ?? 'milliliter';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _quantityController.dispose();
    _packSizeController.dispose();
    _priceController.dispose();
    _brandFocus.dispose();
    _quantityFocus.dispose();
    _packSizeFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await showProductPicker(
      context,
      householdId: widget.householdId,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedProductId = picked.id;
      _selectedProductName = picked.canonicalName;
      _nameController.text = picked.canonicalName;
    });
  }

  String? _errorMessage;

  void _save() {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final quantity = Validators.parseDecimal(_quantityController.text);
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Ürün adı gerekli');
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => _errorMessage = 'Geçerli bir miktar gir');
      return;
    }
    setState(() => _errorMessage = null);
    final packSize = _selectedUnit == 'piece'
        ? Validators.parseDecimal(_packSizeController.text)
        : null;
    Navigator.pop(
      context,
      ReceiptLineEdit(
        locationId: _selectedLocationId,
        productId: _selectedProductId,
        name: _nameController.text.trim(),
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        quantity: quantity,
        unit: _selectedUnit,
        // Paket boyutu yalnızca 'piece' birimi için anlamlı — birim
        // değiştiyse veya alan boş bırakıldıysa null gönderilir.
        packSize: packSize,
        packUnit: _selectedUnit == 'piece' && packSize != null
            ? _selectedPackUnit
            : null,
        price: Validators.parseDecimal(_priceController.text),
        categoryKey: _selectedCategoryKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Satırı Düzelt'),
        actions: [TextButton(onPressed: _save, child: const Text('Kaydet'))],
      ),
      body: SafeArea(
        child: AppFormScroll(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Fişte yazan: "${item.rawText}"',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _selectedLocationId,
                decoration: const InputDecoration(
                  labelText: 'Bölüm',
                  prefixIcon: Icon(Icons.kitchen_rounded),
                ),
                hint: const Text('Bölüm seç'),
                items: [
                  for (final location in widget.locations)
                    DropdownMenuItem(
                      value: location.id,
                      child: Text(location.name),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedLocationId = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.search_rounded),
                label: Text(_selectedProductName),
                onPressed: _pickProduct,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                // OCR'dan gelen ürün adları otokorreksiyonla bozuluyordu.
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _brandFocus.requestFocus(),
                decoration: const InputDecoration(labelText: 'Ürün adı'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _brandController,
                focusNode: _brandFocus,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _quantityFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Marka (opsiyonel)',
                  helperText: 'Girdiğin marka bir daha hatırlanır',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppNumberField(
                controller: _quantityController,
                focusNode: _quantityFocus,
                textInputAction: _selectedUnit == 'piece'
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) => _selectedUnit == 'piece'
                    ? _packSizeFocus.requestFocus()
                    : _save(),
                decoration: const InputDecoration(labelText: 'Miktar'),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _selectedUnit,
                decoration: const InputDecoration(labelText: 'Birim'),
                items: [
                  for (final unit in unitOptions)
                    DropdownMenuItem(value: unit, child: Text(unitLabel(unit))),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedUnit = value);
                },
              ),
              if (_selectedUnit == 'piece') ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppNumberField(
                        controller: _packSizeController,
                        focusNode: _packSizeFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _priceFocus.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Paket boyutu (opsiyonel)',
                          helperText: 'örn. 6 adet × 200 ml için 200 yaz',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedPackUnit,
                        decoration: const InputDecoration(labelText: 'Birim'),
                        items: [
                          for (final unit in unitOptions.where(
                            (u) => u != 'piece',
                          ))
                            DropdownMenuItem(
                              value: unit,
                              child: Text(unitShortLabel(unit)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPackUnit = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppNumberField(
                controller: _priceController,
                focusNode: _priceFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Fiyat (opsiyonel)',
                  prefixText: '₺ ',
                  helperText: 'Satırın fiş üzerindeki toplam tutarı',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryKey,
                decoration: const InputDecoration(
                  labelText: 'Kategori (opsiyonel)',
                  helperText: 'Doğru kategori tarif önerilerini iyileştirir',
                ),
                hint: const Text('Kategori seç'),
                items: [
                  for (final category in widget.categories)
                    DropdownMenuItem(
                      value: category.key,
                      child: Text(category.nameTr),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedCategoryKey = value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                FormErrorText(_errorMessage!),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: _save, child: const Text('Kaydet')),
            ],
          ),
        ),
      ),
    );
  }
}
