import 'package:flutter/material.dart';

/// Premium kullanıcıların seçebildiği arka plan paletleri. Yalnızca YÜZEY
/// ailesi (arka plan, kart, navbar tonları, ikincil konteyner) değişir —
/// marka rengi (yeşil primary) ve depo renkleri (AppColors) sabit kalır.
/// `mint` varsayılan ve bugünkü renklerle BİREBİR aynı (override yok).
enum AppPalette { mint, lavender, peach, sky, sand, slate }

class _Surfaces {
  const _Surfaces({
    required this.surface,
    required this.lowest,
    required this.low,
    required this.container,
    required this.high,
    required this.highest,
    required this.onVariant,
    required this.outline,
    required this.outlineVariant,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
  });

  final Color surface;
  final Color lowest;
  final Color low;
  final Color container;
  final Color high;
  final Color highest;
  final Color onVariant;
  final Color outline;
  final Color outlineVariant;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
}

extension AppPaletteX on AppPalette {
  String get label => switch (this) {
    AppPalette.mint => 'Nane',
    AppPalette.lavender => 'Lavanta',
    AppPalette.peach => 'Şeftali',
    AppPalette.sky => 'Gökyüzü',
    AppPalette.sand => 'Kum',
    AppPalette.slate => 'Arduvaz',
  };

  /// Seçicide gösterilen temsilî renk noktası.
  Color get swatch => switch (this) {
    AppPalette.mint => const Color(0xFFB7E0C6),
    AppPalette.lavender => const Color(0xFFCDBDF2),
    AppPalette.peach => const Color(0xFFF7BFA3),
    AppPalette.sky => const Color(0xFFA5CDF0),
    AppPalette.sand => const Color(0xFFE6D5A3),
    AppPalette.slate => const Color(0xFFB4BEC9),
  };

  /// Taban şemanın yüzey ailesini palete göre değiştirir. mint → aynen döner.
  ColorScheme applyTo(ColorScheme base) {
    if (this == AppPalette.mint) return base;
    final s = (base.brightness == Brightness.dark ? _dark : _light)[this]!;
    return base.copyWith(
      surface: s.surface,
      surfaceContainerLowest: s.lowest,
      surfaceContainerLow: s.low,
      surfaceContainer: s.container,
      surfaceContainerHigh: s.high,
      surfaceContainerHighest: s.highest,
      onSurfaceVariant: s.onVariant,
      outline: s.outline,
      outlineVariant: s.outlineVariant,
      secondaryContainer: s.secondaryContainer,
      onSecondaryContainer: s.onSecondaryContainer,
    );
  }
}

const _light = <AppPalette, _Surfaces>{
  AppPalette.lavender: _Surfaces(
    surface: Color(0xFFF8F6FC),
    lowest: Color(0xFFFFFFFF),
    low: Color(0xFFF2EFF8),
    container: Color(0xFFECE8F4),
    high: Color(0xFFE6E2EF),
    highest: Color(0xFFE2DEEA),
    onVariant: Color(0xFF47434F),
    outline: Color(0xFF7A7583),
    outlineVariant: Color(0xFFCAC4D3),
    secondaryContainer: Color(0xFFE4DCF5),
    onSecondaryContainer: Color(0xFF1F1635),
  ),
  AppPalette.peach: _Surfaces(
    surface: Color(0xFFFFF8F4),
    lowest: Color(0xFFFFFFFF),
    low: Color(0xFFFCF1EA),
    container: Color(0xFFF6EBE3),
    high: Color(0xFFF0E5DC),
    highest: Color(0xFFEADFD6),
    onVariant: Color(0xFF52443E),
    outline: Color(0xFF85746C),
    outlineVariant: Color(0xFFD8C2B8),
    secondaryContainer: Color(0xFFFFDFCF),
    onSecondaryContainer: Color(0xFF2E1508),
  ),
  AppPalette.sky: _Surfaces(
    surface: Color(0xFFF4F9FD),
    lowest: Color(0xFFFFFFFF),
    low: Color(0xFFEDF3F8),
    container: Color(0xFFE7EEF4),
    high: Color(0xFFE1E8EF),
    highest: Color(0xFFDBE3EA),
    onVariant: Color(0xFF3F4850),
    outline: Color(0xFF6F7881),
    outlineVariant: Color(0xFFC0C7CF),
    secondaryContainer: Color(0xFFD0E4F5),
    onSecondaryContainer: Color(0xFF0B1E2E),
  ),
  AppPalette.sand: _Surfaces(
    surface: Color(0xFFFBF8F1),
    lowest: Color(0xFFFFFFFF),
    low: Color(0xFFF6F2E8),
    container: Color(0xFFF0ECE1),
    high: Color(0xFFEAE6DB),
    highest: Color(0xFFE4E0D5),
    onVariant: Color(0xFF4A463B),
    outline: Color(0xFF7B7668),
    outlineVariant: Color(0xFFCFC8B6),
    secondaryContainer: Color(0xFFEBE2C8),
    onSecondaryContainer: Color(0xFF241C06),
  ),
  AppPalette.slate: _Surfaces(
    surface: Color(0xFFF5F7F9),
    lowest: Color(0xFFFFFFFF),
    low: Color(0xFFEFF1F4),
    container: Color(0xFFE9ECEF),
    high: Color(0xFFE3E6EA),
    highest: Color(0xFFDDE1E5),
    onVariant: Color(0xFF41474D),
    outline: Color(0xFF70767D),
    outlineVariant: Color(0xFFC2C7CC),
    secondaryContainer: Color(0xFFD8DEE5),
    onSecondaryContainer: Color(0xFF141C24),
  ),
};

const _dark = <AppPalette, _Surfaces>{
  AppPalette.lavender: _Surfaces(
    surface: Color(0xFF141218),
    lowest: Color(0xFF0F0D13),
    low: Color(0xFF1B181F),
    container: Color(0xFF1F1C24),
    high: Color(0xFF2A262F),
    highest: Color(0xFF35313A),
    onVariant: Color(0xFFCAC4D3),
    outline: Color(0xFF948E9C),
    outlineVariant: Color(0xFF49454F),
    secondaryContainer: Color(0xFF42395A),
    onSecondaryContainer: Color(0xFFE4DCF5),
  ),
  AppPalette.peach: _Surfaces(
    surface: Color(0xFF181210),
    lowest: Color(0xFF120D0B),
    low: Color(0xFF201914),
    container: Color(0xFF241D18),
    high: Color(0xFF2F2721),
    highest: Color(0xFF3A322C),
    onVariant: Color(0xFFD8C2B8),
    outline: Color(0xFFA08C82),
    outlineVariant: Color(0xFF52443E),
    secondaryContainer: Color(0xFF5A3A28),
    onSecondaryContainer: Color(0xFFFFDFCF),
  ),
  AppPalette.sky: _Surfaces(
    surface: Color(0xFF0F141A),
    lowest: Color(0xFF0A0F14),
    low: Color(0xFF161C22),
    container: Color(0xFF1A2026),
    high: Color(0xFF242A31),
    highest: Color(0xFF2F353C),
    onVariant: Color(0xFFBFC8D2),
    outline: Color(0xFF89939D),
    outlineVariant: Color(0xFF3F4851),
    secondaryContainer: Color(0xFF2F4558),
    onSecondaryContainer: Color(0xFFD0E4F5),
  ),
  AppPalette.sand: _Surfaces(
    surface: Color(0xFF16140E),
    lowest: Color(0xFF100E09),
    low: Color(0xFF1E1B13),
    container: Color(0xFF221F17),
    high: Color(0xFF2D2A21),
    highest: Color(0xFF38352C),
    onVariant: Color(0xFFD0C8B6),
    outline: Color(0xFF998F7C),
    outlineVariant: Color(0xFF4A463B),
    secondaryContainer: Color(0xFF4F4528),
    onSecondaryContainer: Color(0xFFEBE2C8),
  ),
  AppPalette.slate: _Surfaces(
    surface: Color(0xFF111417),
    lowest: Color(0xFF0C0F12),
    low: Color(0xFF181C20),
    container: Color(0xFF1C2024),
    high: Color(0xFF262A2F),
    highest: Color(0xFF31353A),
    onVariant: Color(0xFFC2C7CC),
    outline: Color(0xFF8C9298),
    outlineVariant: Color(0xFF41474D),
    secondaryContainer: Color(0xFF363F49),
    onSecondaryContainer: Color(0xFFD8DEE5),
  ),
};
