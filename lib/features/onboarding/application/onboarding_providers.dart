import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Açılıştaki tam ekran tanıtım (IntroScreen) görüldü mü —
/// theme_providers.dart ile aynı SharedPreferences deseni. "v1" sürüm
/// eki, tanıtım içeriği ileride köklü değişirse (yeni özellik eklenince)
/// tek satır değişiklikle tüm kullanıcılara tekrar gösterilebilsin diye.
const _prefsKey = 'onboarding_seen_v1';

/// Alan ana ekranındaki spotlight turu (coach_tour.dart) görüldü mü —
/// tanıtımdan BAĞIMSIZ bir bayrak: kullanıcı tanıtımı atlayıp turu
/// görebilmeli ya da tersi. Ayarlar'daki "Tanıtımı tekrar göster" ikisini
/// birden sıfırlar.
const _coachTourPrefsKey = 'coach_tour_seen_v1';

class _FlagController extends StateNotifier<bool?> {
  _FlagController(this._key) : super(null) {
    _restore();
  }

  final String _key;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> markSeen() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  Future<void> reset() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

// Geriye dönük uyumluluk: eski adla dışarıya açık kalsın (settings_screen
// vb. bu tipi import ediyordu).
typedef OnboardingSeenController = _FlagController;

/// null = henüz SharedPreferences'tan okunmadı (ilk frame'de tanıtım
/// yanlışlıkla gösterilmesin/gizlenmesin diye ayırt edilir).
final onboardingSeenProvider = StateNotifierProvider<_FlagController, bool?>((ref) {
  return _FlagController(_prefsKey);
});

final coachTourSeenProvider = StateNotifierProvider<_FlagController, bool?>((ref) {
  return _FlagController(_coachTourPrefsKey);
});
