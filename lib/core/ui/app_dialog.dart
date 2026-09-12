import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../haptics.dart';
import 'adaptive.dart';
import 'app_prompt_sheet.dart';

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
              title: Text(
                title,
                style: cupertinoDialogTitleStyle(dialogContext),
              ),
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
                      backgroundColor: isDestructive ? colorScheme.error : null,
                      foregroundColor: isDestructive
                          ? colorScheme.onError
                          : null,
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
              : Text(
                  message,
                  style: cupertinoDialogMessageStyle(dialogContext),
                ),
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
  /// KAPANMAZ. Varsayılan validator boş metni reddeder.
  ///
  /// Gövde artık bir alert DEĞİL, bir sheet (`showAppPromptSheet`) —
  /// kullanıcı gerçek cihazda metin girişi içeren alert'lerin ("Ne
  /// almalıyım?" AI önerisi, Ayarlar'daki ad/şifre girişleri) UX olarak
  /// yanlış olduğunu bildirdi. İmza aynı kaldığı için 5 çağrı yerinin
  /// hiçbiri değişmedi, davranış tek yerden (`app_prompt_sheet.dart`) gelir.
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
    // Bunlar eklenmeden önce settings_screen'deki şifre değiştir/hesap
    // sil akışları bu dialogu `autofillHints` OLMADAN kullanıyordu — iOS
    // Keychain'in "şifreni güncelle" önerisi hiç tetiklenmiyordu.
    Iterable<String>? autofillHints,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool autocorrect = true,
    bool enableSuggestions = true,
  }) {
    // cancelLabel artık kullanılmıyor (sheet'in kapatma butonu ✕) — imzada
    // kalması geriye dönük uyumluluk için, çağıran taraflar dokunulmadı.
    return showAppPromptSheet(
      context,
      title: title,
      hintText: hintText,
      confirmLabel: confirmLabel,
      message: message,
      initialText: initialText,
      obscureText: obscureText,
      maxLines: maxLines,
      suffixBuilder: suffixBuilder,
      keyboardType: keyboardType,
      validator: validator,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
    );
  }
}
