import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/form_error_text.dart';
import 'app_sheet.dart';
import 'app_text_field.dart';

/// Tek metin alanı isteyen akışlar için sheet — `AppDialog.prompt`'un
/// gövdesi. Kullanıcı gerçek cihazda "Ne almalıyım?" (AI alışveriş önerisi,
/// çok satırlı + mikrofon) gibi bir isteğin alert kutusuna sıkıştırılmasını
/// "UX olarak çok yanlış, alerti bu tarz şeyler için kullanmamalısın" diye
/// tarif etti. Bu sheet aynı sözleşmeyi (validator inline hata verirse
/// KAPANMAZ, iptal null döner) korur, sadece yüzeyi değişir.
Future<String?> showAppPromptSheet(
  BuildContext context, {
  required String title,
  required String hintText,
  String confirmLabel = 'Kaydet',
  String? message,
  String? initialText,
  bool obscureText = false,
  int maxLines = 1,
  Widget Function(TextEditingController controller)? suffixBuilder,
  TextInputType? keyboardType,
  String? Function(String value)? validator,
  Iterable<String>? autofillHints,
  TextCapitalization textCapitalization = TextCapitalization.none,
  bool autocorrect = true,
  bool enableSuggestions = true,
}) {
  return showAppSheet<String>(
    context,
    builder: (_, __) => _PromptSheetContent(
      title: title,
      hintText: hintText,
      confirmLabel: confirmLabel,
      message: message,
      initialText: initialText,
      obscureText: obscureText,
      maxLines: maxLines,
      suffixBuilder: suffixBuilder,
      keyboardType: keyboardType,
      validator:
          validator ?? (value) => value.trim().isEmpty ? 'Bir değer gir' : null,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
    ),
  );
}

class _PromptSheetContent extends StatefulWidget {
  const _PromptSheetContent({
    required this.title,
    required this.hintText,
    required this.confirmLabel,
    required this.validator,
    this.message,
    this.initialText,
    this.obscureText = false,
    this.maxLines = 1,
    this.suffixBuilder,
    this.keyboardType,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  final String title;
  final String hintText;
  final String confirmLabel;
  final String? Function(String value) validator;
  final String? message;
  final String? initialText;
  final bool obscureText;
  final int maxLines;
  final Widget Function(TextEditingController controller)? suffixBuilder;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  State<_PromptSheetContent> createState() => _PromptSheetContentState();
}

class _PromptSheetContentState extends State<_PromptSheetContent> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final error = widget.validator(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: widget.title,
      onClose: () => Navigator.of(context).pop(),
      onConfirm: _confirm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppTextField(
            controller: _controller,
            autofocus: false,
            obscureText: widget.obscureText,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            keyboardType: widget.keyboardType,
            autofillHints: widget.autofillHints,
            textCapitalization: widget.textCapitalization,
            autocorrect: widget.autocorrect,
            enableSuggestions: widget.enableSuggestions,
            textInputAction: widget.maxLines > 1
                ? TextInputAction.newline
                : TextInputAction.done,
            decoration: InputDecoration(
              hintText: widget.hintText,
              suffixIcon: widget.suffixBuilder?.call(_controller),
            ),
            onSubmitted: (_) => _confirm(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            FormErrorText(_error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _confirm,
              child: Text(widget.confirmLabel),
            ),
          ),
        ],
      ),
    );
  }
}
