import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';
import 'auth_interceptor.dart';

/// Tek Dio instance'ı — tüm feature repository'leri bunu kullanır.
/// onUnauthorized callback'i router'a bağlanır (login'e yönlendirme).
class ApiClient {
  ApiClient({required Future<void> Function() onUnauthorized})
      : tokenStorage = TokenStorage(const FlutterSecureStorage()),
        dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 45), // fiş işleme uzun sürebilir
        )) {
    dio.interceptors.add(AuthInterceptor(tokenStorage: tokenStorage, onUnauthorized: onUnauthorized));
  }

  final Dio dio;
  final TokenStorage tokenStorage;
}
