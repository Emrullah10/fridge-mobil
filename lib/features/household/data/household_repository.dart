import '../../../core/api/api_client.dart';

class Household {
  const Household({required this.id, required this.name, this.kind = 'home'});

  final String id;
  final String name;

  /// 'home' | 'office' | 'summerhouse' | 'other' — backend household_kind
  /// enum'ı. Eski kayıtlarda alan gelmeyebileceği için varsayılan 'home'.
  final String kind;

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String? ?? 'home',
      );
}

class StorageLocation {
  const StorageLocation({required this.id, required this.name, required this.kind});

  final String id;
  final String name;
  final String kind;

  factory StorageLocation.fromJson(Map<String, dynamic> json) => StorageLocation(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String,
      );
}

class HouseholdRepository {
  HouseholdRepository(this._client);

  final ApiClient _client;

  Future<List<Household>> listHouseholds() async {
    final response = await _client.dio.get('/households');
    final households = response.data['households'] as List;
    return households.map((h) => Household.fromJson(h as Map<String, dynamic>)).toList();
  }

  Future<Household> createHousehold(String name, {String kind = 'home'}) async {
    final response = await _client.dio.post('/households', data: {'name': name, 'kind': kind});
    return Household.fromJson(response.data['household'] as Map<String, dynamic>);
  }

  Future<List<StorageLocation>> listLocations(String householdId) async {
    final response = await _client.dio.get('/households/$householdId/locations');
    final locations = response.data['locations'] as List;
    return locations.map((l) => StorageLocation.fromJson(l as Map<String, dynamic>)).toList();
  }

  Future<String> createInvite(String householdId) async {
    final response = await _client.dio.post('/households/$householdId/invites', data: {});
    return response.data['invite']['code'] as String;
  }

  Future<void> acceptInvite(String code) async {
    await _client.dio.post('/invites/$code/accept');
  }
}
