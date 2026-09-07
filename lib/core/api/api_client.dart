import 'dart:io' show Platform;

import 'package:dio/dio.dart';

import '../error/api_error.dart';
import '../storage/token_storage.dart';
import 'api_config.dart';
import 'auth_interceptor.dart';

/// Tek Dio instance'ı — tüm feature repository'leri bunu kullanır.
/// onUnauthorized callback'i router'a bağlanır (login'e yönlendirme).
/// onPlanLimitReached callback'i (opsiyonel) 402 gövdesini entitlements
/// provider'ına ve paywall tetikleyicisine iletir — ApiClient billing
/// katmanını hiç bilmez (auth_providers.dart'taki onUnauthorized ile aynı
/// çapraz-katman haberleşme deseni, dairesel import riski yok).
/// `/households/<id>/...` yollarındaki id'yi ayıklar — 404 interceptor'ı
/// hangi alanın artık erişilemez olduğunu bulmak için kullanır.
final _householdIdInPath = RegExp(r'/households/([^/]+)');

class ApiClient {
  ApiClient({
    required Future<void> Function() onUnauthorized,
    void Function(PlanLimitInfo info)? onPlanLimitReached,
    void Function(String householdId)? onHouseholdNotFound,
  })  : tokenStorage = TokenStorage(),
        dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          // Fiş tarama Ollama'ya gidiyor; OLLAMA_MODEL gemma3:12b'ye
          // geçtikten sonra (2026-08-17) tek istek ~55sn sürebiliyor
          // (qwen2.5'te ~20-25sn'ydi, eski 45sn limiti buradan kalmaydı).
          receiveTimeout: const Duration(seconds: 90),
          // Backend platform bazlı limit çözüyor (bkz. plans.js §Faz D) —
          // Android varsayılan daha cömert, iOS henüz yok ama başlık
          // şimdiden doğru gönderilsin diye Platform.isIOS kontrol edilir.
          headers: {'X-Client-Platform': Platform.isIOS ? 'ios' : 'android'},
        )) {
    dio.interceptors.add(AuthInterceptor(tokenStorage: tokenStorage, onUnauthorized: onUnauthorized));
    if (onPlanLimitReached != null) {
      dio.interceptors.add(InterceptorsWrapper(
        onError: (error, handler) {
          final info = PlanLimitInfo.tryParse(error);
          if (info != null) onPlanLimitReached(info);
          return handler.next(error);
        },
      ));
    }
    if (onHouseholdNotFound != null) {
      // Ekranda bayat bir alan id'si kalmışsa (silinmiş alan, ya da
      // misafirken kayıt olup kimlik değiştikten sonra eski alanın id'si
      // taşınmaya devam ediyorsa) backend her istekte 404 döner ve kullanıcı
      // hatayı görüp takılı kalırdı — bkz. .wolf/buglog.json, 2026-09-06.
      // Bu, o durumda alan listesini tazeleyip kullanıcıyı geri çıkarmak
      // için sinyal verir.
      dio.interceptors.add(InterceptorsWrapper(
        onError: (error, handler) {
          if (error.response?.statusCode == 404) {
            final match = _householdIdInPath.firstMatch(error.requestOptions.path);
            if (match != null) onHouseholdNotFound(match.group(1)!);
          }
          return handler.next(error);
        },
      ));
    }
  }

  final Dio dio;
  final TokenStorage tokenStorage;
}
