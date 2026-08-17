import 'package:flutter_dotenv/flutter_dotenv.dart';

/// .env dosyasından API_BASE_URL okur. main() içinde dotenv.load()
/// çağrılmadan önce erişilirse boş döner — bkz. lib/main.dart.
class ApiConfig {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000/api';
}
