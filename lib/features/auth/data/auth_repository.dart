import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';

class AppUser {
  const AppUser({required this.id, required this.email, required this.displayName});

  final String id;
  final String email;
  final String displayName;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
      );
}

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'displayName': displayName,
    });
    return AppUser.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> login({required String email, required String password}) async {
    final response = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = response.data as Map<String, dynamic>;
    await _client.tokenStorage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final refreshToken = await _client.tokenStorage.readRefreshToken();
    try {
      await _client.dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    } on DioException {
      // Sunucuya ulaşamasak bile yerel token'ları temizlemek yeterli.
    }
    await _client.tokenStorage.clear();
  }

  Future<bool> hasStoredSession() async {
    final token = await _client.tokenStorage.readRefreshToken();
    return token != null;
  }

  Future<void> deleteAccount({required String password}) async {
    await _client.dio.delete('/auth/me', data: {'password': password});
    await _client.tokenStorage.clear();
  }
}
