import 'package:flutter/material.dart';

import '../haptics.dart';
import 'adaptive.dart';

/// iOS'ta herhangi bir metin/sayı alanına odaklanınca klavyenin üstünde
/// beliren "‹ › Bitti" barı — hem gezinme (bir sonraki/önceki alana atla)
/// hem kapatma (klavyeyi indir) sağlar. Android'de HİÇ gösterilmez (sistem
/// klavyesinin zaten Return/Done tuşu var, ayrıca bar eklemek yerlisiz
/// durur).
///
/// Önceden yalnız `AppNumberField` içine gömülüydü (iOS sayısal klavyenin
/// Return tuşu OLMADIĞI için zorunluydu — bkz. eski not orada). Kullanıcı
/// "tüm bu tarz ekranların hepsinde böyle olmalı" dediği için mekanizma
/// buraya taşındı; hem `AppNumberField` hem `AppTextField` bunu kullanır.
///
/// `StatefulWidget`'a mixin edilir: `initState`'te [attachKeyboardToolbar],
/// `dispose`'ta [detachKeyboardToolbar] çağrılmalı, widget `focusNode`
/// alanını sağlamalı.
mixin KeyboardToolbarMixin<T extends StatefulWidget> on State<T> {
  FocusNode get toolbarFocusNode;
  ValueChanged<String>? get toolbarOnSubmitted;
  String Function() get toolbarCurrentText;

  OverlayEntry? _toolbarEntry;

  void attachKeyboardToolbar() {
    toolbarFocusNode.addListener(_handleFocusChange);
  }

  void detachKeyboardToolbar() {
    toolbarFocusNode.removeListener(_handleFocusChange);
    _removeToolbar();
  }

  void _handleFocusChange() {
    if (!isCupertino(context)) return;
    if (toolbarFocusNode.hasFocus) {
      _showToolbar();
    } else {
      _removeToolbar();
    }
  }

  void _showToolbar() {
    _removeToolbar();
    final overlay = Overlay.of(context, rootOverlay: true);
    _toolbarEntry = OverlayEntry(
      builder: (context) => KeyboardToolbar(
        onPrevious: () {
          AppHaptics.selection();
          FocusScope.of(context).previousFocus();
        },
        onNext: () {
          AppHaptics.selection();
          FocusScope.of(context).nextFocus();
        },
        onDone: () {
          AppHaptics.selection();
          toolbarFocusNode.unfocus();
          toolbarOnSubmitted?.call(toolbarCurrentText());
        },
      ),
    );
    overlay.insert(_toolbarEntry!);
  }

  void _removeToolbar() {
    _toolbarEntry?.remove();
    _toolbarEntry = null;
  }
}

/// Klavye üstünde beliren "‹ › Bitti" barı — [KeyboardToolbarMixin]
/// tarafından bir `OverlayEntry` içine çizilir, doğrudan kullanılmaz.
class KeyboardToolbar extends StatelessWidget {
  const KeyboardToolbar({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.onDone,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: viewInsets.bottom,
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        child: SafeArea(
          top: false,
          bottom: false,
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: onPrevious,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: onNext,
                ),
                const Spacer(),
                TextButton(onPressed: onDone, child: const Text('Bitti')),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
