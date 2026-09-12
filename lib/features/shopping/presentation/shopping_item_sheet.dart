import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_number_field.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/unit_label.dart';
import '../data/shopping_repository.dart';

class ShoppingItemEdit {
  const ShoppingItemEdit({
    required this.quantity,
    required this.unit,
    this.note,
  });
  final double quantity;
  final String unit;
  final String? note;
}

/// Miktar/birim/not düzenleme sheet'i — hem manuel ekleme hem mevcut kalemi
/// düzenleme için kullanılır.
Future<ShoppingItemEdit?> showShoppingItemSheet(
  BuildContext context, {
  ShoppingItem? existing,
}) {
  return showAppSheet<ShoppingItemEdit>(
    context,
    builder: (_, __) => _ShoppingItemSheet(existing: existing),
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
  late final _noteController = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  final _noteFocus = FocusNode();
  late String _unit = widget.existing?.unit ?? 'piece';

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final quantity = Validators.parseDecimal(_quantityController.text) ?? 1;
    Navigator.of(context).pop(
      ShoppingItemEdit(
        quantity: quantity,
        unit: _unit,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Önceden elle yazılmış Padding+SafeArea; `AppSheetScaffold` kullanmayan
    // tek sheet'ti — SingleChildScrollView olmadığı için küçük ekranda
    // (iPhone SE) klavye + 2 alan + dropdown + buton overflow riski
    // taşıyordu. Diğer 6 sheet'le aynı kabuğa taşındı.
    return AppSheetScaffold(
      title: widget.existing?.name ?? 'Ürün Düzenle',
      onClose: () => Navigator.of(context).pop(),
      onConfirm: _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppNumberField(
                  controller: _quantityController,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _noteFocus.requestFocus(),
                  decoration: const InputDecoration(labelText: 'Miktar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Birim'),
                  items: [
                    for (final u in unitOptions)
                      DropdownMenuItem(value: u, child: Text(unitLabel(u))),
                  ],
                  onChanged: (value) => setState(() => _unit = value ?? _unit),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _noteController,
            focusNode: _noteFocus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Not (opsiyonel)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
