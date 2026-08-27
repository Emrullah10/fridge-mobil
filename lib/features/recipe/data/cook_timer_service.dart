import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Adım adım pişirme modundaki geri sayım bittiğinde bir bildirim gösterir.
///
/// Bilinçli olarak basit: uygulama ön plandayken çalışan bir Timer + bittiğinde
/// `show()`. `zonedSchedule` (timezone paketi + tam-alarm izni) kapsam dışı —
/// mutfakta telefon açık ve elde tutuluyor senaryosu hedefleniyor. PushService
/// ile de kasıtlı olarak bağlanmadı: kendi kanalı, kendi id aralığı.
class CookTimerService {
  CookTimerService._();
  static final CookTimerService instance = CookTimerService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationChannel(
    'fridge_cook_timer',
    'Pişirme Zamanlayıcısı',
    description: 'Adım adım pişirme modundaki geri sayım bildirimleri',
    importance: Importance.max,
  );

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> notifyStepDone({required int stepOrder, required String recipeTitle}) async {
    try {
      await _ensureInit();
      await _plugin.show(
        900000 + stepOrder, // pişirme timer'ları için ayrı id aralığı
        'Süre doldu — Adım $stepOrder',
        recipeTitle,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
      );
    } catch (e) {
      debugPrint('CookTimerService.notifyStepDone error: $e');
    }
  }
}
