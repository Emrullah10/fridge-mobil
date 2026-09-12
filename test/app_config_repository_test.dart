import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mobil/core/api/api_client.dart';
import 'package:fridge_mobil/core/version/app_config_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerçek network hiç açılmadan isteği yakalayan sahte adapter — sadece
/// query parametrelerini kaydedip sabit bir başarılı yanıt döner.
class _CapturingAdapter implements HttpClientAdapter {
  Uri? capturedUri;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedUri = options.uri;
    final body =
        '{"latestVersion":"1.0.5","minSupportedVersion":"1.0.0","storeUrl":"https://example.com"}';
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');
    // ApiClient -> AuthInterceptor -> TokenStorage, macOS test ortamında
    // (Platform.isIOS/isAndroid false) SharedPreferences'a düşüyor —
    // mock'lanmazsa MissingPluginException fırlatıp isteği DioException'a
    // çevirir.
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'isIos: false iken platform query eklenmez (Android/diğer davranışı)',
    () async {
      final client = ApiClient(onUnauthorized: () async {});
      final adapter = _CapturingAdapter();
      client.dio.httpClientAdapter = adapter;

      final config = await AppConfigRepository(client, isIos: false).fetch();

      expect(config, isNotNull);
      expect(config!.latestVersion, '1.0.5');
      expect(
        adapter.capturedUri?.queryParameters.containsKey('platform'),
        isFalse,
      );
    },
  );

  test('isIos: true iken ?platform=ios eklenir', () async {
    final client = ApiClient(onUnauthorized: () async {});
    final adapter = _CapturingAdapter();
    client.dio.httpClientAdapter = adapter;

    await AppConfigRepository(client, isIos: true).fetch();

    expect(adapter.capturedUri?.queryParameters['platform'], 'ios');
  });
}
