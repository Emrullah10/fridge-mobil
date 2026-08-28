import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../navigation/app_page_transitions.dart';

/// Uygulama genelinde tek gerçek kaynak: renkler, boşluklar, köşe
/// yuvarlaklığı. Yeni bir ekran eklerken buradaki token'ları kullan,
/// renk/boşluk değerini elle yazma.
///
/// Kaynak: Stitch "Fridge Fresh" tasarım sistemi (projects/5194790141640215989).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  /// FAB'lı ekranlarda listenin altına bırakılan boşluk (xl * 2).
  static const fabBottomPadding = 64.0;

  /// Form ekranlarında (Giriş/Kayıt/Dolaba Ekle) kenar boşluğu.
  static const layoutMarginForm = lg;

  /// Genel liste/envanter ekranlarında kenar boşluğu.
  static const layoutMarginStandard = md;
}

abstract final class AppRadius {
  static const card = 16.0;
  static const button = 12.0;
  static const input = 12.0;
  static const dialog = 16.0;
  static const snackbar = 12.0;

  /// Miktar rozeti, "Bitti" rozeti, marka/"Kontrol et" hap rozeti.
  static const pill = 999.0;

  /// Bölüm ikon kutusu — Stitch tasarımında tam daire olarak çizilmiş.
  static const iconBox = 999.0;

  /// Logo kutusu (72×72).
  static const logo = 20.0;
}

/// Storage location renkleri ve durum renkleri — Material seed paletinden
/// gelmez, Stitch "Fridge Fresh" designMd'de elle sabitlenmiştir. Tüm
/// uygulamada bölüm rengi burada tek kaynaktan okunmalı; ekran dosyalarına
/// hex kopyalanmaz.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.storageFridge,
    required this.storageFreezer,
    required this.storagePantry,
    required this.storageOther,
    required this.statusWarning,
  });

  final Color storageFridge;
  final Color storageFreezer;
  final Color storagePantry;
  final Color storageOther;
  final Color statusWarning;

  static const light = AppColors(
    storageFridge: Color(0xFF3B82F6),
    storageFreezer: Color(0xFF06B6D4),
    storagePantry: Color(0xFFB45309),
    storageOther: Color(0xFF6B7280),
    statusWarning: Color(0xFFB45309),
  );

  // Koyu tema: bölüm kimliği (mavi/turkuaz) korunur ama koyu yüzey (#0F1512)
  // üstünde AA-altı kalan kehribar ve gri tonlar açığa çekilir — light'taki
  // #B45309 ≈ 3.4:1, #6B7280 ≈ 3.2:1 idi (normal metinde okunmuyordu).
  // Yeni değerler koyu yüzey üstünde ≥ 4.5:1.
  static const dark = AppColors(
    storageFridge: Color(0xFF7BB5FF),
    storageFreezer: Color(0xFF4DD4E8),
    storagePantry: Color(0xFFE8A33D),
    storageOther: Color(0xFF9CA3AF),
    statusWarning: Color(0xFFE8A33D),
  );

  @override
  AppColors copyWith({
    Color? storageFridge,
    Color? storageFreezer,
    Color? storagePantry,
    Color? storageOther,
    Color? statusWarning,
  }) {
    return AppColors(
      storageFridge: storageFridge ?? this.storageFridge,
      storageFreezer: storageFreezer ?? this.storageFreezer,
      storagePantry: storagePantry ?? this.storagePantry,
      storageOther: storageOther ?? this.storageOther,
      statusWarning: statusWarning ?? this.statusWarning,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      storageFridge: Color.lerp(storageFridge, other.storageFridge, t)!,
      storageFreezer: Color.lerp(storageFreezer, other.storageFreezer, t)!,
      storagePantry: Color.lerp(storagePantry, other.storagePantry, t)!,
      storageOther: Color.lerp(storageOther, other.storageOther, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  static ThemeData light() => _base(brightness: Brightness.light);
  static ThemeData dark() => _base(brightness: Brightness.dark);

  static ThemeData _base({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark ? _darkColorScheme : _lightColorScheme;
    final appColors = isDark ? AppColors.dark : AppColors.light;

    final baseTextTheme = GoogleFonts.interTextTheme();
    final textTheme = _buildTextTheme(baseTextTheme, colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [appColors],
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        // GoogleFonts.interTextTheme() argümansız çağrıldığında her zaman
        // ThemeData.light()'ın (siyaha yakın) renklerinden başlıyor — bu
        // alanlar açıkça set edilmezse Flutter dahili olarak bodyLarge'a
        // düşer ve koyu temada etiket/girilen metin görünmez hale gelir.
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.dialog)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.all(textTheme.labelSmall),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.secondaryContainer,
        labelStyle: textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, thickness: 1),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.snackbar)),
      ),
      // Tüm push/pop geçişleri tek noktadan — bkz. app_page_transitions.dart.
      // Mevcut çıplak MaterialPageRoute çağrılarının hiçbirine dokunmadan
      // uygulanır (platform builder'ı override eder).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, ColorScheme colorScheme) {
    // GoogleFonts.interTextTheme() argümansız çağrıldığında HER ZAMAN
    // ThemeData.light()'ın (siyaha yakın) renklerinden başlıyor —
    // AppTheme.dark() içinde çağrılsa bile. base.apply(...) ile tüm
    // roller (displayLarge..labelSmall) tek seferde colorScheme.onSurface'a
    // bağlanır; aşağıdaki copyWith ise yalnızca fontSize/weight/height gibi
    // Stitch tipografi rollerini özelleştirir. Böylece gelecekte yeni bir
    // TextTheme rolü kullanılırsa (örn. bodyLarge, labelLarge) o da doğru
    // temaya bağlı renk alır — tek tek unutma riski kalmaz.
    final tinted = base.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
      decorationColor: colorScheme.onSurface,
    );
    return tinted.copyWith(
      // hero-display: 28/700 — Giriş ekranı "Fridge" başlığı.
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        color: colorScheme.onSurface,
      ),
      // section-title: 22/700 — bölüm başlıkları.
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 28 / 22,
        color: colorScheme.onSurface,
      ),
      // appbar-title: 20/600 — sola dayalı AppBar başlıkları.
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 26 / 20,
        color: colorScheme.onSurface,
      ),
      // card-title: 16/600 — ürün adı, ev adı, bölüm adı.
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
        color: colorScheme.onSurface,
      ),
      // body-md: 14/400.
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: colorScheme.onSurface,
      ),
      // body-secondary: 14/400, ikincil renk.
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: colorScheme.onSurfaceVariant,
      ),
      // badge-label: 11/700.
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 14 / 11,
        color: colorScheme.onSurface,
      ),
      // button-text: 16/600.
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  // Stitch designMd birebir hex değerleri (Açık tema).
  static const _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF096444),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF2E7D5B),
    onPrimaryContainer: Color(0xFFD0FFE3),
    secondary: Color(0xFF4E6355),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFCEE5D4),
    onSecondaryContainer: Color(0xFF0C1F14),
    tertiary: Color(0xFF0053B4),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF156BDE),
    onTertiaryContainer: Color(0xFFF2F3FF),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFF6FBF5),
    onSurface: Color(0xFF181D19),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF0F5EF),
    surfaceContainer: Color(0xFFEAEFE9),
    surfaceContainerHigh: Color(0xFFE4EAE4),
    surfaceContainerHighest: Color(0xFFE1E4DF),
    onSurfaceVariant: Color(0xFF404943),
    outline: Color(0xFF6F7A72),
    outlineVariant: Color(0xFFC0C9C0),
    inverseSurface: Color(0xFF2C322E),
    onInverseSurface: Color(0xFFEDF2EC),
    inversePrimary: Color(0xFF88D6AF),
    surfaceTint: Color(0xFF176B4B),
  );

  // Stitch designMd birebir hex değerleri (Koyu tema — Stitch'in 21
  // ekranın yarısında çizdiği koyu ekranlardan türetilmiştir).
  static const _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF88D6AF),
    onPrimary: Color(0xFF00301A),
    primaryContainer: Color(0xFF005236),
    onPrimaryContainer: Color(0xFFA4F3CA),
    secondary: Color(0xFFB5CCBB),
    onSecondary: Color(0xFF213528),
    secondaryContainer: Color(0xFF374B3E),
    onSecondaryContainer: Color(0xFFD1E8D6),
    tertiary: Color(0xFFADC6FF),
    onTertiary: Color(0xFF002E69),
    tertiaryContainer: Color(0xFF004395),
    onTertiaryContainer: Color(0xFFD8E2FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0F1512),
    onSurface: Color(0xFFDFE4DE),
    surfaceContainerLowest: Color(0xFF0A0F0C),
    surfaceContainerLow: Color(0xFF171D19),
    surfaceContainer: Color(0xFF1B211D),
    surfaceContainerHigh: Color(0xFF252B27),
    surfaceContainerHighest: Color(0xFF303632),
    onSurfaceVariant: Color(0xFFBEC9C1),
    outline: Color(0xFF89938B),
    outlineVariant: Color(0xFF3F4943),
    inverseSurface: Color(0xFFDFE4DE),
    onInverseSurface: Color(0xFF2C322E),
    inversePrimary: Color(0xFF096444),
    surfaceTint: Color(0xFF88D6AF),
  );
}
