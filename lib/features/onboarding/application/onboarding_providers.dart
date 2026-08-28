import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Açılıştaki tam ekran tanıtım (IntroScreen) görüldü mü —
/// theme_providers.dart ile aynı SharedPreferences deseni. "v1" sürüm
/// eki, tanıtım içeriği ileride köklü değişirse (yeni özellik eklenince)
/// tek satır değişiklikle tüm kullanıcılara tekrar gösterilebilsin diye.
const _prefsKey = 'onboarding_seen_v1';

/// Ekran başına spotlight turları. Her ana ekran ilk kez açıldığında kendi
/// mini turu çalışır; her turun kendi kalıcı bayrağı var. `householdHome`'un
/// anahtarı ESKİ isimde (`coach_tour_seen_v1`) bırakıldı — mevcut kullanıcılar
/// gördükleri turu tekrar görmesin. Tanıtımdan (IntroScreen) bağımsız:
/// kullanıcı tanıtımı atlayıp turları görebilir ya da tersi. Ayarlar'daki
/// "Tanıtımı tekrar göster" hepsini birden sıfırlar.
enum CoachTourId {
  householdHome('coach_tour_seen_v1'),
  inventory('coach_tour_inventory_v1'),
  shopping('coach_tour_shopping_v1'),
  recipes('coach_tour_recipes_v1'),
  insights('coach_tour_insights_v1');

  const CoachTourId(this.prefsKey);
  final String prefsKey;
}

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

/// Ekran başına tur bayrağı — `tourSeenProvider(CoachTourId.inventory)` gibi.
final tourSeenProvider = StateNotifierProvider.family<_FlagController, bool?, CoachTourId>(
  (ref, id) => _FlagController(id.prefsKey),
);
