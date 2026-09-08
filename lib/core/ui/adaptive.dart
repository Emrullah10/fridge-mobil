import 'package:flutter/material.dart';

/// Uygulamadaki TÜM platform ayrışması (Cupertino mu Material mi) BU
/// dosyadan geçer — başka hiçbir dosyada `Theme.of(context).platform` ya da
/// `TargetPlatform` kontrolü yazma. Tek noktadan yönetildiği için CI'da
/// `grep -rn "TargetPlatform" lib` ile bu kısıt makineyle korunabilir.
///
/// `defaultTargetPlatform` DEĞİL `Theme.of(context).platform` kullanılıyor:
/// testte `ThemeData.copyWith(platform: ...)` ile ezilebilir, global state
/// sızdırmaz ve üretimdeki gerçek kod yolunu test eder (bkz.
/// `pageTransitionsTheme` zaten aynı ekseni kullanıyor).
bool isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// `CupertinoAlertDialog`/`CupertinoActionSheet` başlık ve içerik
/// slotlarının stilini `CupertinoTextThemeData`'dan ALMADIĞINI unutma —
/// kendi sabit SF Pro stillerini dayatırlar. Bu yüzden slotlara hazır
/// stillenmiş `Text` veriyoruz; sadece RENK token'dan gelir, boyut/aile
/// iOS'un kendi dialog tipografisine (17/13pt) yakın tutulur.
TextStyle cupertinoDialogTitleStyle(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  return (textTheme.titleSmall ?? const TextStyle()).copyWith(
    fontSize: 17,
    height: 22 / 17,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

TextStyle cupertinoDialogMessageStyle(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  return (textTheme.bodyMedium ?? const TextStyle()).copyWith(
    fontSize: 13,
    height: 18 / 13,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
