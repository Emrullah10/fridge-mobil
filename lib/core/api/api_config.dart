/// Geliştirme sırasında `--dart-define=API_BASE_URL=http://192.168.1.x:4000/api`
/// ile fiziksel cihazdan test edilebilir. Android emulator'da host makineye
/// erişim için 10.0.2.2 kullanılır, iOS simulator'da localhost çalışır.
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api',
  );
}
