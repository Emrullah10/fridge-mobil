import 'package:flutter/material.dart';

import 'app_keyboard_toolbar.dart';

/// iOS'ta sayısal klavyenin (`TextInputType.number` / `numberWithOptions`)
/// Return tuşu OLMADIĞINI unutma — bu yüzden `textInputAction` bu klavye
/// türünde etkisizdir. Uygulamada 9 sayısal alan vardı ve hiçbirinde
/// klavyeyi kapatmanın/ilerlemenin discoverable bir yolu yoktu (tek çıkış:
/// boş yere dokunmak). `AppNumberField` bunu [KeyboardToolbarMixin] ile
/// simüle edilmiş klavye-üstü toolbar'la ("‹ › Bitti") çözer — aynı
/// mekanizmayı metin alanları için `AppTextField` de kullanır.
///
/// Ondalık ayrıştırma her zaman `Validators.parseDecimal` üzerinden
/// yapılmalı — TR klavyede ondalık tuşu VİRGÜLdür, çıplak
/// `double.tryParse` kullanıcının "1,5" girdisini sessizce reddeder.
class AppNumberField extends StatefulWidget {
  const AppNumberField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.decimal = true,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;

  /// `false` ise tam sayı klavyesi (`TextInputType.number`), `true` ise
  /// ondalık nokta/virgül içeren klavye (`numberWithOptions(decimal: true)`).
  final bool decimal;

  /// iOS'ta yalnızca toolbar YOKKEN (Android'de veya toolbar gizliyken)
  /// anlamlıdır — Android sayısal klavyesinde Return tuşu vardır ve bu
  /// `textInputAction`'ı kullanır. iOS'ta toolbar'ın "Bitti"si her zaman
  /// `unfocus()` yapar, `onSubmitted`'i tetikler.
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;

  @override
  State<AppNumberField> createState() => _AppNumberFieldState();
}

class _AppNumberFieldState extends State<AppNumberField>
    with KeyboardToolbarMixin<AppNumberField> {
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
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      decoration: widget.decoration,
    );
  }
}
