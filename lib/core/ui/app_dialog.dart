import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/form_error_text.dart';
import 'adaptive.dart';

/// Uygulamadaki TÜM basit dialog ihtiyaçları için tek çağrı noktası.
/// Platform ayrışması (iOS -> Cupertino, Android -> Material) burada
/// yaşar — çağıran taraf tek satır kalır, iki varyantı elle yazmaz.
abstract final class AppDialog {
  /// İki seçenekli onay. Kullanıcı iptal ederse/barrier'a dokunursa (yalnız
  /// Android'de mümkün) `false` döner — ASLA null dönmez, çağıran tarafta
  /// `if (!await AppDialog.confirm(...)) return;` kalıbı yeterlidir.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Onayla',
    String cancelLabel = 'Vazgeç',
    bool isDestructive = false,
    // Yalnızca Material (Android) dalında çizilir — iOS'ta
    // `isDestructiveAction`'ın kırmızı metni zaten HIG sinyali, ayrıca bir
    // ikon eklemek iOS'ta yabancı durur.
    IconData? icon,
  }) async {
    if (isDestructive) AppHaptics.destructive();

    final result = isCupertino(context)
        ? await showCupertinoDialog<bool>(
            context: context,
            // Cupertino varsayılanı false: HIG'de alert dışına dokunup
            // kapatmak beklenmez, kullanıcı bir aksiyon seçmeli.
            barrierDismissible: false,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: Text(title, style: cupertinoDialogTitleStyle(dialogContext)),
              content: message == null
                  ? null
                  : Text(
                      message,
                      style: cupertinoDialogMessageStyle(dialogContext),
                    ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(cancelLabel),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: isDestructive,
                  isDefaultAction: !isDestructive,
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          )
        : await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) {
              final colorScheme = Theme.of(dialogContext).colorScheme;
              return AlertDialog(
                icon: icon == null
                    ? null
                    : Icon(
                        icon,
                        color: isDestructive
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                title: Text(title),
                content: message == null ? null : Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(cancelLabel),
                  ),
                  FilledButton(
                    // filledButtonTheme.minimumSize = Size.fromHeight(52) =
                    // Size(infinity, 52) — AlertDialog.actions bir
                    // OverflowBar'dır, sonsuz genişlik isteği taşma
                    // algılatıp butonları dikey moda düşürür. Burada ez.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor:
                          isDestructive ? colorScheme.error : null,
                      foregroundColor:
                          isDestructive ? colorScheme.onError : null,
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(confirmLabel),
                  ),
                ],
              );
            },
          );
    return result ?? false;
  }

  /// Tek düğmeli bilgilendirme.
  static Future<void> alert(
    BuildContext context, {
    required String title,
    String? message,
    String dismissLabel = 'Tamam',
  }) async {
    if (isCupertino(context)) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(title, style: cupertinoDialogTitleStyle(dialogContext)),
          content: message == null
              ? null
              : Text(message, style: cupertinoDialogMessageStyle(dialogContext)),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dismissLabel),
            ),
          ],
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: message == null ? null : Text(message),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dismissLabel),
            ),
          ],
        ),
      );
    }
  }

  /// Tek metin alanı + onay — `showSingleFieldDialog`'un yerine geçer.
  /// Kullanıcı iptal ederse `null` döner. `validator` null dönerse geçerli
  /// kabul edilir; String dönerse o metin inline hata olarak gösterilir ve
  /// dialog KAPANMAZ. Varsayılan validator boş metni reddeder.
  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    required String hintText,
    String confirmLabel = 'Kaydet',
    String cancelLabel = 'İptal',
    String? message,
    String? initialText,
    bool obscureText = false,
    int maxLines = 1,
    Widget Function(TextEditingController controller)? suffixBuilder,
    TextInputType? keyboardType,
    String? Function(String value)? validator,
  }) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierLabel: title,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _PromptDialog(
          title: title,
          hintText: hintText,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          message: message,
          initialText: initialText,
          obscureText: obscureText,
          maxLines: maxLines,
          suffixBuilder: suffixBuilder,
          keyboardType: keyboardType,
          validator: validator ??
              (value) => value.trim().isEmpty ? 'Bir değer gir' : null,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // showDialog/showCupertinoDialog'un varsayılan fade+scale'ini
        // showGeneralDialog ile birebir taklit ediyoruz (StatefulWidget
        // içeriği barındırabilmek için showGeneralDialog'a geçtik).
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 150),
    );
  }
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.hintText,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.validator,
    this.message,
    this.initialText,
    this.obscureText = false,
    this.maxLines = 1,
    this.suffixBuilder,
    this.keyboardType,
  });

  final String title;
  final String hintText;
  final String confirmLabel;
  final String cancelLabel;
  final String? Function(String value) validator;
  final String? message;
  final String? initialText;
  final bool obscureText;
  final int maxLines;
  final Widget Function(TextEditingController controller)? suffixBuilder;
  final TextInputType? keyboardType;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
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
    if (isCupertino(context)) {
      return CupertinoAlertDialog(
        title: Text(widget.title, style: cupertinoDialogTitleStyle(context)),
        content: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.message != null) ...[
                Text(widget.message!, style: cupertinoDialogMessageStyle(context)),
                const SizedBox(height: AppSpacing.sm),
              ],
              CupertinoTextField(
                controller: _controller,
                placeholder: widget.hintText,
                autofocus: true,
                obscureText: widget.obscureText,
                maxLines: widget.maxLines,
                keyboardType: widget.keyboardType,
                suffix: widget.suffixBuilder?.call(_controller),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _confirm(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _error != null
                        ? CupertinoColors.destructiveRed
                        : CupertinoColors.systemGrey4,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                FormErrorText(_error!),
              ],
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.cancelLabel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _confirm,
            child: Text(widget.confirmLabel),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: AppSpacing.sm),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: widget.obscureText,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            decoration: InputDecoration(
              hintText: widget.hintText,
              suffixIcon: widget.suffixBuilder?.call(_controller),
              errorText: _error,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirm(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
