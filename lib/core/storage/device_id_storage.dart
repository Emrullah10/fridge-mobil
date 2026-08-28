import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Misafir hesap için kalıcı cihaz kimliği. token_storage.dart ile aynı
/// depolama deseni — iOS/Android'de Keychain/Keystore, masaüstünde
/// SharedPreferences fallback'i (Keychain imzasız build'de çalışmıyor).
///
/// Bu kimlik backend'e `POST /auth/guest` ile gönderilir — aynı cihaz
/// uygulamayı kapatıp açtığında ya da 401 sonrası yeniden bağlandığında
/// AYNI misafir hesabına dönmesini sağlar (backend `guest_device_id` unique
/// index'i ile eşler).
class DeviceIdStorage {
  DeviceIdStorage([FlutterSecureStorage? secureStorage]) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;
  static const _key = 'guest_device_id';

  bool get _useSecureStorage => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<String?> _read() {
    if (_useSecureStorage) return _secureStorage.read(key: _key);
    return SharedPreferences.getInstance().then((prefs) => prefs.getString(_key));
  }

  Future<void> _write(String value) async {
    if (_useSecureStorage) {
      await _secureStorage.write(key: _key, value: value);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }

  String _generateId() {
    final random = Random.secure();
    // Backend en az 8 karakter istiyor (auth.routes.js /guest doğrulaması) —
    // 32 hex karakter (16 byte) hem yeterince benzersiz hem kısa.
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Kayıtlı bir cihaz kimliği varsa onu döner, yoksa üretip kalıcı olarak
  /// saklar. İdempotent — aynı cihazda tekrar tekrar çağrılabilir.
  Future<String> getOrCreate() async {
    final existing = await _read();
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _generateId();
    await _write(generated);
    return generated;
  }
}
