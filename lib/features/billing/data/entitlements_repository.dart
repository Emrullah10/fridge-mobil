import '../../../core/api/api_client.dart';
import '../domain/entitlements.dart';

class EntitlementsRepository {
  EntitlementsRepository(this._client);

  final ApiClient _client;

  Future<Entitlements> fetch() async {
    final response = await _client.dio.get('/me/entitlements');
    return Entitlements.fromJson(response.data as Map<String, dynamic>);
  }

  /// Play'in 2026 zorunluluğu: uygulama içinden en fazla 2 dokunuşta iptal
  /// (bkz. plan §Faz 5). Backend `productId` parametresine göre doğrudan
  /// abonelik yönetim ekranına ya da genel listeye yönlendiren bir deep
  /// link üretir.
  Future<String> fetchManageSubscriptionUrl({String? productId}) async {
    final response = await _client.dio.get(
      '/me/subscription/manage-url',
      queryParameters: productId != null ? {'productId': productId} : null,
    );
    return response.data['url'] as String;
  }
}
