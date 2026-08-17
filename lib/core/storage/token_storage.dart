import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Access + refresh token'larını saklar.
///
/// iOS/Android'de Keychain/Keystore (donanım destekli şifreli depolama)
/// kullanılır — gerçek kullanıcıların token'ları böyle korunur.
///
/// macOS/Windows/Linux masaüstünde ise SharedPreferences'a düşülür: macOS'ta
/// Keychain yalnızca Apple geliştirici sertifikasıyla imzalanmış uygulamalarda
/// çalışır (imzasız build'de `-34018: A required entitlement isn't present`
/// hatası verir). Masaüstü yalnızca geliştirme sırasında kullanıldığı için
/// bu makul bir taviz; üretimde dağıtılan platformlar (iOS/Android) güvenli
/// depolamayı kullanmaya devam eder.
abstract interface class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _SecureTokenStore implements TokenStore {
  const _SecureTokenStore(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class _PreferencesTokenStore implements TokenStore {
  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

/// Mobilde güvenli depolama, masaüstünde SharedPreferences seçer.
TokenStore _defaultTokenStore() {
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    return const _SecureTokenStore(FlutterSecureStorage());
  }
  return _PreferencesTokenStore();
}

class TokenStorage {
  TokenStorage([TokenStore? store]) : _store = store ?? _defaultTokenStore();

  final TokenStore _store;
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<String?> readAccessToken() => _store.read(_accessTokenKey);
  Future<String?> readRefreshToken() => _store.read(_refreshTokenKey);

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _store.write(_accessTokenKey, accessToken);
    await _store.write(_refreshTokenKey, refreshToken);
  }

  Future<void> saveAccessToken(String token) => _store.write(_accessTokenKey, token);

  Future<void> clear() async {
    await _store.delete(_accessTokenKey);
    await _store.delete(_refreshTokenKey);
  }
}
