import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının Ayarlar > Görünüm'den seçtiği yazı boyutu çarpanı. Cihazın
/// sistem yazı ölçeğiyle ÇARPILIR (bkz. main.dart builder) — erişilebilirlik
/// ayarı yok sayılmaz. Varsayılan 1.0 = bugünkü davranış.
const _prefsKey = 'text_scale_v1';

const kTextScaleSmall = 0.9;
const kTextScaleNormal = 1.0;
const kTextScaleLarge = 1.15;

const kTextScaleOptions = [kTextScaleSmall, kTextScaleNormal, kTextScaleLarge];

class TextScaleController extends StateNotifier<double> {
  TextScaleController() : super(kTextScaleNormal) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_prefsKey);
      if (saved != null && kTextScaleOptions.contains(saved)) state = saved;
    } catch (_) {
      // Okunamazsa varsayılan ölçekle devam.
    }
  }

  Future<void> setScale(double scale) async {
    state = scale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKey, scale);
    } catch (_) {
      // Kalıcı yazılamasa da oturum boyunca uygulanır.
    }
  }
}

final textScaleProvider = StateNotifierProvider<TextScaleController, double>(
  (ref) => TextScaleController(),
);
