import '../config/app_env.dart';

/// API_BASE_URL derleme zamanında --dart-define ile geçirilir
/// (bkz. lib/core/config/app_env.dart) — önceden .env dosyasından
/// (flutter_dotenv) okunuyordu.
class ApiConfig {
  static String get baseUrl => AppEnv.apiBaseUrl;
}
