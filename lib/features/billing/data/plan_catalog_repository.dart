import '../../../core/api/api_client.dart';
import '../domain/plan_catalog.dart';

/// entitlements_repository.dart ile aynı desen — tek fark: /plans auth
/// gerektirmez, misafir/oturumsuz kullanıcıya da (onboarding tanıtımı)
/// çağrılabilir.
class PlanCatalogRepository {
  PlanCatalogRepository(this._client);

  final ApiClient _client;

  Future<PlanCatalog> fetch() async {
    final response = await _client.dio.get('/plans');
    return PlanCatalog.fromJson(response.data as Map<String, dynamic>);
  }
}
