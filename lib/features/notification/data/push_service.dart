import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_repository.dart';

/// Bildirime tıklandığında (uygulama arka planda/kapalıyken) nereye
/// yönlendirileceğini üst katmana (main.dart _AuthGate) iletmek için — push
/// servisi navigasyondan bihaber olmalı, sadece "şuraya git" payload'ını taşır.
typedef PushNotificationTapHandler = void Function(Map<String, dynamic> data);

/// Uygulama arka planda/kapalıyken gelen FCM mesajları — Android'de
/// top-level (isolate dışı çağrılabilir) bir fonksiyon olmalı, flutter
/// tarafından zorunlu kılınıyor. Sadece cihaz durum bar'ına ekler, veri
/// işlemez (arka plan isolate'inde riverpod/provider erişimi olmaz).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka planda hiçbir şey yapmaya gerek yok — FCM bildirimi (notification
  // payload'ı doluysa) sistem zaten kendisi gösteriyor. Sadece burada var
  // olmak, Firebase'in `onBackgroundMessage` gereksinimini karşılıyor.
}

/// Firebase Cloud Messaging kayıt/refresh mantığını sarmalayan servis.
/// Giriş yapıldıktan sonra bir kez başlatılır (_AuthGate), çıkışta token
/// backend'den silinir (paylaşılan cihazda eski kullanıcının bildirim
/// almaya devam etmesini önlemek için — bkz. backend auth.routes.js logout).
class PushService {
  PushService(this._repo);

  final NotificationRepository _repo;
  String? _currentToken;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;
  PushNotificationTapHandler? _onTap;

  static const _androidChannel = AndroidNotificationChannel(
    'fridge_default',
    'Fridge Bildirimleri',
    description: 'Fiş, davet ve envanter bildirimleri',
    importance: Importance.high,
  );

  Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    _localNotificationsInitialized = true;
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        // Foreground'da gösterilen local notification'a tıklanması.
        final payload = response.payload;
        if (payload == null) return;
        _onTap?.call(Uri.splitQueryString(payload));
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  /// [onTap] payload'daki `data` map'iyle çağrılır — RECEIPT_PROCESSED gibi
  /// tiplerde `scanId`/`householdId` taşır, çağıran taraf buna göre
  /// yönlendirir (bkz. main.dart).
  Future<void> registerForCurrentUser({PushNotificationTapHandler? onTap}) async {
    _onTap = onTap;
    await _initLocalNotifications();

    final messaging = FirebaseMessaging.instance;

    // iOS/web'de izin istemi zorunlu; Android 13+ için de gerekli (13
    // öncesinde otomatik granted döner).
    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await messaging.getToken();
    if (token != null) {
      await _sendToken(token);
    }

    // Token FCM tarafından herhangi bir zamanda (uygulama silinip
    // yüklendiğinde, cihaz değiştiğinde vb.) değişebilir.
    FirebaseMessaging.instance.onTokenRefresh.listen(_sendToken);

    // Uygulama ön plandayken FCM'in kendisi hiçbir şey göstermez (data-only
    // payload varsayımıyla) — foreground'da heads-up bildirimi biz
    // gösteriyoruz, aksi halde kullanıcı analiz bittiğini asla görmez.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Bildirime tıklanıp uygulama arka plandan öne getirildiğinde.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _onTap?.call(message.data);
    });

    // Uygulama tamamen kapalıyken bildirime tıklanıp açıldığında.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _onTap?.call(initialMessage.data);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: Uri(queryParameters: message.data).query,
    );
  }

  Future<void> _sendToken(String token) async {
    _currentToken = token;
    try {
      await _repo.registerDevice(token, platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
    } catch (_) {
      // Token kaydı başarısız olsa bile uygulama akışı bloklanmasın —
      // bir sonraki açılışta / token refresh'te tekrar denenir.
    }
  }

  Future<void> unregister() async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await _repo.unregisterDevice(token);
    } catch (_) {
      // Çıkış akışını bloklamaya değmez.
    }
    _currentToken = null;
  }
}
