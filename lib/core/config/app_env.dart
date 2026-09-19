/// Derleme zamanı ortam değişkenleri — `--dart-define` ile geçirilir.
///
/// Önceden bu değerler bir `.env` dosyasından (flutter_dotenv,
/// pubspec.yaml'da asset olarak bildirilmişti) okunuyordu — bu da .env
/// dosyasını olduğu gibi (düz metin) her yayınlanan APK/AAB'nin içine
/// gömüyordu. RevenueCat public anahtarları (`goog_`/`appl_`) zaten
/// istemciye gömülmek üzere tasarlanmış, ama .env bir Flutter asset'i
/// olduğu için oraya eklenecek HERHANGİ bir değer (ör. ileride bir sunucu
/// anahtarı) aynı şekilde düz metin sızardı — asıl risk buydu.
///
/// `String.fromEnvironment` derleme zamanında sabitlere gömer (runtime'da
/// dosya okuma yok); değerler yine tersine mühendislikle çıkarılabilir
/// (RC public key'leri için bu zaten beklenen), ama artık ayrı, okunabilir
/// bir `.env` dosyası olarak paket içinde durmuyorlar.
///
/// Kullanım — flutter run/build'e eklenir:
///   --dart-define=API_BASE_URL=https://api-fridge.emrullahbozkurt.com/api
///   --dart-define=REVENUECAT_API_KEY=goog_...
///   --dart-define=REVENUECAT_API_KEY_IOS=appl_...
///
/// Geliştirme kolaylığı için `flutter_launch.json`/IDE run config'lerine
/// bu define'lar eklenmeli (bkz. README/`.vscode` veya `.idea` run
/// configuration'ları) — CLI'da tek tek yazmak yerine.
class AppEnv {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api',
  );

  static const String revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
  );

  static const String revenueCatApiKeyIos = String.fromEnvironment(
    'REVENUECAT_API_KEY_IOS',
  );
}
