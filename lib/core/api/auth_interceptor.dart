import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';

/// Her isteğe access token ekler. 401 alındığında refresh token ile yeni
/// bir access token alıp isteği bir kez tekrar dener. Refresh de başarısız
/// olursa onUnauthorized çağrılır (login ekranına yönlendirme burada tetiklenir).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStorage,
    required this.onUnauthorized,
  }) : _refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  final TokenStorage tokenStorage;
  final Dio _refreshDio;
  final Future<void> Function() onUnauthorized;

  bool _isRefreshing = false;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers['X-Client-Type'] = 'mobile';
    final accessToken = await tokenStorage.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isRetry = err.requestOptions.extra['retried'] == true;

    if (!isUnauthorized || isRetry || _isRefreshing) {
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      final refreshToken = await tokenStorage.readRefreshToken();
      if (refreshToken == null) {
        await onUnauthorized();
        return handler.next(err);
      }

      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'X-Client-Type': 'mobile'}),
      );

      final newAccessToken = response.data['accessToken'] as String;
      final newRefreshToken = response.data['refreshToken'] as String;
      await tokenStorage.saveTokens(accessToken: newAccessToken, refreshToken: newRefreshToken);

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      retryOptions.extra['retried'] = true;

      final retryResponse = await _refreshDio.fetch(retryOptions);
      return handler.resolve(retryResponse);
    } catch (_) {
      await onUnauthorized();
      return handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
