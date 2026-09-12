import 'package:flutter/material.dart';

import 'app_keyboard_toolbar.dart';

/// `TextFormField`'ın iOS'ta klavye üstüne "‹ › Bitti" barı takan sürümü —
/// `AppTextField`'ın Form-entegre (validator/autovalidate) karşılığı. Auth
/// ekranları (giriş, kayıt, şifre) `Form` + `validator` kullandığı için
/// düz `AppTextField` yerine bunu alır.
///
/// API'si düz `TextFormField`'a bilerek yakın tutuldu — çağrı yerleri
/// neredeyse birebir `TextFormField` → `AppTextFormField` değişimiyle geçer.
class AppTextFormField extends StatefulWidget {
  const AppTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.maxLines = 1,
    this.autofocus = false,
    this.enabled = true,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.autovalidateMode,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final int? maxLines;
  final bool autofocus;
  final bool enabled;
  final bool autocorrect;
  final bool enableSuggestions;
  final Iterable<String>? autofillHints;
  final String? Function(String? value)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final AutovalidateMode? autovalidateMode;

  @override
  State<AppTextFormField> createState() => _AppTextFormFieldState();
}

class _AppTextFormFieldState extends State<AppTextFormField>
    with KeyboardToolbarMixin<AppTextFormField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();

  @override
  FocusNode get toolbarFocusNode => _focusNode;
  @override
  ValueChanged<String>? get toolbarOnSubmitted => widget.onFieldSubmitted;
  // TextFormField kendi iç controller'ını (widget.controller == null iken)
  // dışarı vermiyor — "Bitti"nin onSubmitted'i tetiklemesi için asıl metne
  // ihtiyaç yok, boş geçiliyor (mevcut sözleşme: onDone yalnızca unfocus +
  // callback tetikler, callback'in text argümanı auth ekranlarında zaten
  // kullanılmıyor).
  @override
  String Function() get toolbarCurrentText =>
      () => widget.controller?.text ?? '';

  @override
  void initState() {
    super.initState();
    attachKeyboardToolbar();
  }

  @override
  void dispose() {
    detachKeyboardToolbar();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      obscureText: widget.obscureText,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      autovalidateMode: widget.autovalidateMode,
    );
  }
}
