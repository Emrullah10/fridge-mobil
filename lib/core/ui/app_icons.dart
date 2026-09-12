import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive.dart';

/// Uygulamanın "kabuk" ikonları (kapat, geri, artı, sil, paylaş, ara,
/// ayarlar, onay, takvim, göz aç/kapa, kilit, posta, bildirim, daha-fazla)
/// %100 Material'dı — iOS'ta bunlar kullanıcının platform dili olarak
/// okuduğu ikonlar, alan-özgü metaforlardan (kitchen/garage/warehouse gibi
/// 130 farklı ikon — bunların CupertinoIcons karşılığı yok, illüstratif
/// öğe olarak Material'da KALIYOR) farklı.
///
/// `isCupertino(context)`'e göre doğru seti döndürür. Yeni bir kabuk ikonu
/// gerektiğinde buraya eklenir — ekran kodunda doğrudan `Icons.` veya
/// `CupertinoIcons.` yazılmaz.
abstract final class AppIcons {
  static IconData close(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.xmark : Icons.close_rounded;

  static IconData back(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.back : Icons.arrow_back_rounded;

  static IconData chevronForward(BuildContext context) => isCupertino(context)
      ? CupertinoIcons.chevron_forward
      : Icons.chevron_right_rounded;

  static IconData add(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.add : Icons.add_rounded;

  static IconData delete(BuildContext context) => isCupertino(context)
      ? CupertinoIcons.delete
      : Icons.delete_outline_rounded;

  /// iOS'ta "kutu + yukarı ok" (`Icons.ios_share`, Material'ın kendi iOS
  /// taklidi) — `Icons.share_rounded` (üç nokta bağlantılı ok) Android
  /// paylaşım simgesidir, iOS'ta yanlış tanınır.
  static IconData share(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.share : Icons.ios_share_rounded;

  static IconData search(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.search : Icons.search_rounded;

  static IconData settings(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.settings : Icons.settings_rounded;

  static IconData check(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.check_mark : Icons.check_rounded;

  static IconData calendar(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.calendar : Icons.event_rounded;

  static IconData eye(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.eye : Icons.visibility_outlined;

  static IconData eyeOff(BuildContext context) => isCupertino(context)
      ? CupertinoIcons.eye_slash
      : Icons.visibility_off_outlined;

  static IconData lock(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.lock : Icons.lock_outline;

  static IconData mail(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.mail : Icons.mail_outline;

  static IconData notification(BuildContext context) => isCupertino(context)
      ? CupertinoIcons.bell
      : Icons.notifications_none_rounded;

  static IconData moreHorizontal(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.ellipsis : Icons.more_horiz_rounded;
}
