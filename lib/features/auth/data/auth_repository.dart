import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';

class DietProfile {
  const DietProfile({this.allergens = const [], this.diet = 'none', this.dailyKcalTarget});

  final List<String> allergens;
  final String diet;
  final int? dailyKcalTarget;

  bool get isEmpty => allergens.isEmpty && diet == 'none' && dailyKcalTarget == null;

  factory DietProfile.fromJson(Map<String, dynamic> json) => DietProfile(
        allergens: (json['allergens'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        diet: json['diet'] as String? ?? 'none',
        dailyKcalTarget: (json['dailyKcalTarget'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'allergens': allergens,
        'diet': diet,
        'dailyKcalTarget': dailyKcalTarget,
      };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.locale = 'tr',
    this.dietProfile,
    this.isGuest = false,
  });

  final String id;
  final String email;
  final String displayName;
  final String locale;
  final DietProfile? dietProfile;

  /// Sunucuda anonim (misafir) hesap — sentetik email/şifre taşır, kullanıcı
  /// henüz kayıt olmadı. bkz. AuthRepository.createGuest / upgradeAccount.
  final bool isGuest;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        locale: json['locale'] as String? ?? 'tr',
        dietProfile: json['dietProfile'] != null
            ? DietProfile.fromJson(json['dietProfile'] as Map<String, dynamic>)
            : null,
        isGuest: json['isGuest'] as bool? ?? false,
      );
}

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    String? deviceId,
  }) async {
    final response = await _client.dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'displayName': displayName,
      // 14 günlük ters deneme aynı cihazdan ikinci kez alınmasın diye —
      // backend zaten bilmiyorsa (eski sürüm) sessizce yok sayar.
      if (deviceId != null) 'deviceId': deviceId,
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

  /// Misafir hesap açar (ya da aynı deviceId için mevcut misafiri döndürür)
  /// — kayıt duvarı olmadan uygulamanın tamamını kullanabilme.
  Future<AppUser> createGuest(String deviceId) async {
    final response = await _client.dio.post('/auth/guest', data: {'deviceId': deviceId});
    final data = response.data as Map<String, dynamic>;
    await _client.tokenStorage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Misafir hesabını kalıcı hesaba yükseltir — oturum ve veriler korunur,
  /// yalnızca email/şifre gerçek hale gelir.
  Future<AppUser> upgradeAccount({
    required String email,
    required String password,
    required String displayName,
    String? deviceId,
  }) async {
    final response = await _client.dio.post('/auth/upgrade', data: {
      'email': email,
      'password': password,
      'displayName': displayName,
      if (deviceId != null) 'deviceId': deviceId,
    });
    return AppUser.fromJson(response.data['user'] as Map<String, dynamic>);
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

  Future<AppUser> updateProfile({
    required String displayName,
    String? locale,
    // sentinel: alan hiç geçilmezse dokunulmaz; null geçilirse temizlenir.
    Object? dietProfile = _noDietProfile,
  }) async {
    final response = await _client.dio.patch('/auth/me', data: {
      'displayName': displayName,
      if (locale != null) 'locale': locale,
      if (!identical(dietProfile, _noDietProfile))
        'dietProfile': dietProfile is DietProfile ? dietProfile.toJson() : null,
    });
    return AppUser.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  static const _noDietProfile = Object();

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

  /// Backend her koşulda (kayıtlı e-posta olsun olmasın) 204 döner —
  /// enumeration sızdırmamak için. Oturum durumunu değiştirmez.
  Future<void> requestPasswordReset({required String email}) async {
    await _client.dio.post('/auth/forgot-password', data: {'email': email});
  }

  /// Başarılı olursa şifre değişir ve sunucudaki tüm oturumlar düşer —
  /// kullanıcı bu ekrandan sonra tekrar login olmalı, otomatik giriş yapılmaz.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _client.dio.post('/auth/reset-password', data: {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }
}
