import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access + refresh token'ları cihazda Keychain (iOS) / Keystore (Android)
/// üzerinden şifreli saklar. Backend web'de bunu httpOnly cookie'de tutar;
/// mobilde native cookie jar olmadığı için aynı token'lar burada saklanır.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> saveAccessToken(String token) => _storage.write(key: _accessTokenKey, value: token);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
