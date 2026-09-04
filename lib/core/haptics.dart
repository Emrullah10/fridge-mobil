import 'package:flutter/services.dart';

/// Uygulama genelinde tutarlı, ölçülü dokunsal geri bildirim. Niyet-adlı
/// sarmalayıcılar üzerinden çağrılır ki yoğunluk tek yerden ayarlanabilsin
/// (ör. ileride bir "titreşimi kapat" ayarı eklenirse buraya tek satır).
abstract final class AppHaptics {
  /// Sekme değişimi, onay kutusu gibi hafif/sık etkileşimler.
  static void selection() => HapticFeedback.selectionClick();

  /// Kaydedildi/eklendi gibi başarı anları.
  static void success() => HapticFeedback.lightImpact();

  /// Silme/kaydırıp atma gibi geri dönüşü olan ama dikkat çekmesi gereken
  /// yıkıcı işlemler.
  static void destructive() => HapticFeedback.mediumImpact();
}
