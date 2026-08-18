import 'package:flutter/material.dart';

/// Tek alanlı AlertDialog + İptal/Onay — "Davet Koduyla Katıl" gibi
/// dialoglarının near-identical kopyalarının yerine geçer. `null` döner
/// (kullanıcı iptal ettiyse) veya trim'lenmiş metni döner.
Future<String?> showSingleFieldDialog(
  BuildContext context, {
  required String title,
  required String hintText,
  required String confirmLabel,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: hintText),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal')),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
