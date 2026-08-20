import 'package:dio/dio.dart';

import '../api/api_client.dart';

class AppConfig {
  const AppConfig({required this.latestVersion, required this.minSupportedVersion, required this.storeUrl});

  final String latestVersion;
  final String minSupportedVersion;
  final String storeUrl;

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        latestVersion: json['latestVersion'] as String,
        minSupportedVersion: json['minSupportedVersion'] as String,
        storeUrl: json['storeUrl'] as String,
      );
}

class AppConfigRepository {
  AppConfigRepository(this._client);

  final ApiClient _client;

  /// /app-config authenticate'ten önce mount edilmiş — giriş yapmadan da
  /// erişilebilir (bkz. backend boot.js).
  Future<AppConfig?> fetch() async {
    try {
      final response = await _client.dio.get('/app-config');
      return AppConfig.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      // Sürüm kontrolü best-effort — ağ hatası uygulama açılışını asla
      // engellememeli.
      return null;
    }
  }
}

/// Basit "x.y.z" semver karşılaştırması — pubspec sürüm formatıyla uyumlu,
/// harici paket gerektirmez.
int compareVersions(String a, String b) {
  final partsA = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final partsB = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final va = i < partsA.length ? partsA[i] : 0;
    final vb = i < partsB.length ? partsB[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}
