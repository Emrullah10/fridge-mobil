import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_keyboard_toolbar.dart';

/// `TextField`'ın iOS'ta klavye üstüne "‹ › Bitti" barı takan sürümü —
/// [AppNumberField]'daki mekanizmanın metin alanlarına yayılmış hali.
/// Kullanıcı gerçek cihazda arama/isim/not/şifre gibi her alanda bu barı
/// (Dynalist'teki örnek) istedi; Android'de hiç gösterilmez, sistem
/// klavyesinin zaten Done tuşu var.
///
/// API'si düz `TextField`'a bilerek yakın tutuldu — çağrı yerleri
/// neredeyse birebir `TextField` → `AppTextField` değişimiyle geçer.
///
/// **İstisna:** `TextInputType.visiblePassword` + `digitsOnly` ile kod
/// girişi yapan iki ekran (şifre sıfırlama, alana kod ile katılma) bu
/// sarmalayıcıyı KULLANMAZ — bilerek Return tuşu kazanmış klavyeler,
/// toolbar orada gereksiz.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.enabled = true,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.inputFormatters,
    this.style,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final bool enabled;
  final bool autocorrect;
  final bool enableSuggestions;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField>
    with KeyboardToolbarMixin<AppTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();

  @override
  FocusNode get toolbarFocusNode => _focusNode;
  @override
  ValueChanged<String>? get toolbarOnSubmitted => widget.onSubmitted;
  @override
  String Function() get toolbarCurrentText =>
      () => widget.controller.text;

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
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      obscureText: widget.obscureText,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      inputFormatters: widget.inputFormatters,
      style: widget.style,
    );
  }
}
