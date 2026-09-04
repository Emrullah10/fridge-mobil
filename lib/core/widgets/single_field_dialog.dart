import 'package:flutter/material.dart';

/// Tek alanlı AlertDialog + İptal/Onay — "Davet Koduyla Katıl" gibi
/// dialoglarının near-identical kopyalarının yerine geçer. `null` döner
/// (kullanıcı iptal ettiyse) veya trim'lenmiş metni döner.
Future<String?> showSingleFieldDialog(
  BuildContext context, {
  required String title,
  required String hintText,
  required String confirmLabel,
  bool obscureText = false,
  String? contentText,
  String? initialText,
}) {
  final controller = TextEditingController(text: initialText);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contentText != null) ...[
            Text(contentText),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hintText),
            autofocus: true,
            obscureText: obscureText,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
