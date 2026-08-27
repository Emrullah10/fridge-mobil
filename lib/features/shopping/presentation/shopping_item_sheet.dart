import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unit_label.dart';
import '../data/shopping_repository.dart';

class ShoppingItemEdit {
  const ShoppingItemEdit({required this.quantity, required this.unit, this.note});
  final double quantity;
  final String unit;
  final String? note;
}

/// Miktar/birim/not düzenleme sheet'i — hem manuel ekleme hem mevcut kalemi
/// düzenleme için kullanılır.
Future<ShoppingItemEdit?> showShoppingItemSheet(BuildContext context, {ShoppingItem? existing}) {
  return showModalBottomSheet<ShoppingItemEdit>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ShoppingItemSheet(existing: existing),
  );
}

class _ShoppingItemSheet extends StatefulWidget {
  const _ShoppingItemSheet({this.existing});
  final ShoppingItem? existing;

  @override
  State<_ShoppingItemSheet> createState() => _ShoppingItemSheetState();
}

class _ShoppingItemSheetState extends State<_ShoppingItemSheet> {
  late final _quantityController = TextEditingController(
    text: (widget.existing?.quantity ?? 1).toString(),
  );
  late final _noteController = TextEditingController(text: widget.existing?.note ?? '');
  late String _unit = widget.existing?.unit ?? 'piece';

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1;
    Navigator.of(context).pop(ShoppingItemEdit(
      quantity: quantity,
      unit: _unit,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing?.name ?? 'Ürün Düzenle', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Miktar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Birim'),
                    items: [for (final u in unitOptions) DropdownMenuItem(value: u, child: Text(unitLabel(u)))],
                    onChanged: (value) => setState(() => _unit = value ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Not (opsiyonel)'),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _submit, child: const Text('Kaydet')),
            ),
          ],
        ),
      ),
    );
  }
}
