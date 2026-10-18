import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/billing/application/entitlements_providers.dart';
import 'app_palette.dart';

const _prefsKey = 'theme_palette_v1';

/// Kullanıcının SEÇTİĞİ palet (premium olsun olmasın saklanır — premium'a
/// geçince seçimi kaybolmasın). Uygulanan palet için effectivePaletteProvider.
class ThemePaletteController extends StateNotifier<AppPalette> {
  ThemePaletteController() : super(AppPalette.mint) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_prefsKey);
      state = AppPalette.values.firstWhere(
        (p) => p.name == name,
        orElse: () => AppPalette.mint,
      );
    } catch (_) {
      // Okunamazsa varsayılan palet.
    }
  }

  Future<void> setPalette(AppPalette palette) async {
    state = palette;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, palette.name);
    } catch (_) {
      // Oturum boyunca uygulanır, kalıcı yazılamadı.
    }
  }
}

final themePaletteProvider =
    StateNotifierProvider<ThemePaletteController, AppPalette>(
      (ref) => ThemePaletteController(),
    );

/// Gerçekten UYGULANAN palet: premium/deneme değilse (ör. aboneliği bitmiş)
/// varsayılana düşer. Yetki bilgisi yüklenirken (soğuk açılış) kaydedilen
/// palet korunur — aksi halde premium kullanıcı her açılışta bir an varsayılan
/// rengi görürdü.
final effectivePaletteProvider = Provider<AppPalette>((ref) {
  final saved = ref.watch(themePaletteProvider);
  final entitlements = ref.watch(entitlementsControllerProvider).valueOrNull;
  if (entitlements == null) return saved;
  return (entitlements.isPremium || entitlements.isTrial)
      ? saved
      : AppPalette.mint;
});
