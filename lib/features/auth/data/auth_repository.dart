import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';

class AppUser {
  const AppUser({required this.id, required this.email, required this.displayName, this.locale = 'tr'});

  final String id;
  final String email;
  final String displayName;
  final String locale;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        locale: json['locale'] as String? ?? 'tr',
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

  /// Oturum token'dan geri yüklendiğinde kullanıcı bilgisini (ad/e-posta)
  /// hidre eder — token varlığı tek başına user'ı bilmemize yetmiyordu,
  /// uygulama yeniden açıldığında profil ekranı boş kalıyordu.
  Future<AppUser> fetchCurrentUser() async {
    final response = await _client.dio.get('/auth/me');
    return AppUser.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> updateProfile({required String displayName, String? locale}) async {
    final response = await _client.dio.patch('/auth/me', data: {
      'displayName': displayName,
      if (locale != null) 'locale': locale,
    });
    return AppUser.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _client.dio.post('/auth/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> deleteAccount({required String password}) async {
    await _client.dio.delete('/auth/me', data: {'password': password});
    await _client.tokenStorage.clear();
  }
}
