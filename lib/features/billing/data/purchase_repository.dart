import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat sarmalayıcısı (plan §Faz 5). Bu dosya SDK'nın tüm yüzeyini
/// tek bir yere toplar — ekranlar `Purchases.*`'ı doğrudan çağırmaz, hep
/// bu repository üzerinden geçer (RC'nin API'si değişirse ya da başka bir
/// sağlayıcıya geçilirse tek dosya değişir).
///
/// KURULUM NOTU: gerçek çalışması için main.dart'ta uygulama başlarken
/// `PurchaseRepository.configure(apiKey: ...)` çağrılmalı — apiKey
/// RevenueCat Dashboard > Project Settings > API Keys'ten alınır (Google
/// Play projesi için "Public app-specific API key"). API anahtarı
/// .env'e `REVENUECAT_API_KEY` olarak eklenir (flutter_dotenv zaten
/// projede kurulu, api_config.dart'taki desenle aynı). Anahtar olmadan
/// bu sınıf hiçbir şeyi çökertmez — configure() çağrılmazsa her satın
/// alma denemesi PurchaseException fırlatır, UI bunu describeApiError
/// benzeri bir mesaja çevirir (bkz. subscription_screen.dart).
class PurchaseProduct {
  const PurchaseProduct({
    required this.identifier,
    required this.priceString,
    required this.title,
    required this.description,
  });

  final String identifier;

  /// Mağazadan gelen YERELLEŞTİRİLMİŞ fiyat string'i (ör. "₺79,99") — asla
  /// sabit kodlanmaz (plan §Faz 4 "Paywall içeriği" — Play politikası).
  final String priceString;
  final String title;
  final String description;
}

class PurchaseResult {
  const PurchaseResult({required this.success, this.cancelled = false, this.errorMessage});
  final bool success;
  final bool cancelled;
  final String? errorMessage;
}

/// fetchOfferings()'in üç ayrı "boş" durumu — eskiden hepsi tek bir
/// `const []` altında birleşiyordu, UI hangi sebeple boş olduğunu asla
/// bilemiyordu (bkz. buglog: "abonelik ekranı boş geliyor").
enum OfferingsFailure {
  /// REVENUECAT_API_KEY boş/gömülmemiş — configure() hiç çağrılmadı.
  notConfigured,

  /// RC yapılandırıldı ama Dashboard'da "current" işaretli bir offering
  /// yok / ürünler attach edilmemiş / Play'de ürün henüz aktif değil.
  noOffering,

  /// Purchases.getOfferings() exception fırlattı (ağ hatası, Play Billing
  /// yok, sideload edilmiş debug build vb.) — eskiden hiç yakalanmıyordu.
  storeError,
}

class OfferingsResult {
  const OfferingsResult.success(this.products) : failure = null, debugMessage = null;
  const OfferingsResult.failed(this.failure, {this.debugMessage}) : products = const [];

  final List<PurchaseProduct> products;
  final OfferingsFailure? failure;

  /// Sadece hata ayıklama için — kullanıcıya ham gösterilmez (paywall'da
  /// yalnızca kDebugMode'da küçük gri metin olarak eklenir).
  final String? debugMessage;
}

class PurchaseRepository {
  static bool _configured = false;

  /// main.dart'ta uygulama açılışında BİR KEZ çağrılır. userId verilirse
  /// (kayıtlı kullanıcı) RC app_user_id'yi bizim user.id'imize sabitler —
  /// bu KRİTİK: webhook'un appUserId'si bizim backend'deki kullanıcıyı
  /// bulabilmesi için Purchases.logIn ile aynı id kullanılmalı (plan
  /// §Faz 5 "RC app_user_id == bizim user.id").
  static Future<void> configure({required String apiKey, String? userId}) async {
    if (_configured) return;
    if (apiKey.isEmpty) {
      // Anahtar yoksa (henüz kurulmadı / dev ortamı) sessizce atla — boot
      // asla çökmemeli (config/index.js'teki no-op adaptör ilkesiyle aynı).
      debugPrint('PurchaseRepository: REVENUECAT_API_KEY boş, RevenueCat devre dışı.');
      return;
    }
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
    final configuration = PurchasesConfiguration(apiKey);
    if (userId != null) configuration.appUserID = userId;
    await Purchases.configure(configuration);
    _configured = true;
  }

  /// Kullanıcı login/register/upgrade olduğunda çağrılır — RC'nin anonim
  /// kimliğini bizim gerçek user.id'imize bağlar. Zaten configure() ile
  /// aynı id verilmişse RC bunu no-op sayar.
  static Future<void> logIn(String userId) async {
    if (!_configured) return;
    await Purchases.logIn(userId);
  }

  static Future<void> logOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (_) {
      // Zaten anonim bir kullanıcıysa logOut hata fırlatır — yok say.
    }
  }

  /// Play Console'da tanımlı paketleri (aylık/yıllık) döner — paywall
  /// ekranı bunları listeler. RC'de bir "offering" (varsayılan: "default")
  /// altında toplanır. Üç ayrı "boş" durumu ayırt eder (bkz.
  /// OfferingsFailure) — eskiden hepsi sessizce `[]` dönüyordu ve
  /// getOfferings() bir exception fırlatırsa hiç yakalanmıyordu, bu da
  /// paywall'da sonsuz spinner'a sebep oluyordu.
  Future<OfferingsResult> fetchOfferings() async {
    if (!_configured) return const OfferingsResult.failed(OfferingsFailure.notConfigured);
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null || current.availablePackages.isEmpty) {
        return const OfferingsResult.failed(OfferingsFailure.noOffering);
      }
      return OfferingsResult.success(
        current.availablePackages
            .map((pkg) => PurchaseProduct(
                  identifier: pkg.storeProduct.identifier,
                  priceString: pkg.storeProduct.priceString,
                  title: pkg.storeProduct.title,
                  description: pkg.storeProduct.description,
                ))
            .toList(),
      );
    } catch (e) {
      return OfferingsResult.failed(OfferingsFailure.storeError, debugMessage: e.toString());
    }
  }

  /// Satın alma başlatır. Sonucu backend'e HİÇ bildirmez — RevenueCat
  /// webhook'u zaten otomatik POST /api/billing/webhook'a gönderir (plan
  /// §Faz 5 akış diyagramı). Bu fonksiyon sadece UI'a "başarılı/iptal/hata"
  /// bilgisini döner, entitlement güncellemesi webhook üzerinden asenkron
  /// gelir — bu yüzden satın alma sonrası entitlements_providers.dart'ın
  /// invalidate() çağrısı biraz gecikmeli olabilir (webhook round-trip).
  Future<PurchaseResult> purchase(String productIdentifier) async {
    if (!_configured) {
      return const PurchaseResult(success: false, errorMessage: 'Satın alma şu anda kullanılamıyor.');
    }
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.availablePackages
          .where((p) => p.storeProduct.identifier == productIdentifier)
          .firstOrNull;
      if (package == null) {
        return const PurchaseResult(success: false, errorMessage: 'Ürün bulunamadı.');
      }
      await Purchases.purchase(PurchaseParams.package(package));
      return const PurchaseResult(success: true);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(success: false, cancelled: true);
      }
      return PurchaseResult(success: false, errorMessage: e.message ?? 'Satın alma başarısız oldu.');
    }
  }

  /// "Satın alımları geri yükle" — webhook kaçarsa (nadiren) tek kurtarma
  /// yolu (plan §Faz 5 abonelik yönetim ekranı). RC'nin kendi kayıtlarından
  /// tazeler, bizim backend'imize dokunmaz — geri yükleme sonrası
  /// entitlements_providers.dart'ın invalidate() çağrılması gerekir
  /// (çağıran taraf, subscription_screen.dart bunu yapar).
  Future<bool> restorePurchases() async {
    if (!_configured) return false;
    try {
      await Purchases.restorePurchases();
      return true;
    } catch (_) {
      return false;
    }
  }
}
