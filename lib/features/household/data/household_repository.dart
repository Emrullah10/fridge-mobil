import '../../../core/api/api_client.dart';
import '../../../core/widgets/household_kind.dart';

class Household {
  const Household({required this.id, required this.name, this.kind = 'home', this.features = const {}});

  final String id;
  final String name;

  /// backend household_kind (bkz. core/widgets/household_kind.dart listesi).
  /// Eski kayıtlarda alan gelmeyebileceği için varsayılan 'home'.
  final String kind;

  /// household.features JSONB — şu an tek anahtar: 'food' (bool). Kullanıcı
  /// açıkça karar vermediyse map'te hiç yer almaz, o durumda [foodEnabled]
  /// türden türetir (backend'deki resolveFeatures ile aynı mantık).
  final Map<String, dynamic> features;

  /// Tarifler/AI Chef sekmelerinin görünürlüğü. Kayıtlı bir 'food' değeri
  /// varsa o kullanılır (kullanıcı türü ezmiş demektir), yoksa `foodKinds`
  /// listesinden türetilir.
  bool get foodEnabled {
    final stored = features['food'];
    if (stored is bool) return stored;
    return foodKinds.contains(kind);
  }

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String? ?? 'home',
        features: (json['features'] as Map<String, dynamic>?) ?? const {},
      );
}

class StorageLocation {
  const StorageLocation({
    required this.id,
    required this.name,
    required this.kind,
    this.icon,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String kind;

  /// Serbest ikon seçimi (bkz. core/widgets/storage_kind.dart ikon kataloğu).
  /// null ise `kind`'ın varsayılan ikonu kullanılır.
  final String? icon;
  final int sortOrder;

  factory StorageLocation.fromJson(Map<String, dynamic> json) => StorageLocation(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String,
        icon: json['icon'] as String?,
        sortOrder: json['sortOrder'] as int? ?? 0,
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

  Future<Household> createHousehold(String name, {String kind = 'home', bool? foodEnabled}) async {
    final response = await _client.dio.post(
      '/households',
      data: {
        'name': name,
        'kind': kind,
        if (foodEnabled != null) 'features': {'food': foodEnabled},
      },
    );
    return Household.fromJson(response.data['household'] as Map<String, dynamic>);
  }

  /// Kullanıcının household-profile.js'teki tür varsayımını elle ezmesi —
  /// ör. bir ofis alanında mutfak/tarif özelliklerini sonradan açabilir.
  Future<Household> updateFoodFeature(String householdId, bool foodEnabled) async {
    final response = await _client.dio.patch(
      '/households/$householdId/features',
      data: {'food': foodEnabled},
    );
    return Household.fromJson(response.data['household'] as Map<String, dynamic>);
  }

  Future<List<StorageLocation>> listLocations(String householdId) async {
    final response = await _client.dio.get('/households/$householdId/locations');
    final locations = response.data['locations'] as List;
    return locations.map((l) => StorageLocation.fromJson(l as Map<String, dynamic>)).toList();
  }

  Future<StorageLocation> createLocation(
    String householdId, {
    required String name,
    String? kind,
    String? icon,
  }) async {
    final response = await _client.dio.post(
      '/households/$householdId/locations',
      data: {'name': name, if (kind != null) 'kind': kind, if (icon != null) 'icon': icon},
    );
    return StorageLocation.fromJson(response.data['location'] as Map<String, dynamic>);
  }

  Future<StorageLocation> updateLocation(
    String householdId,
    String locationId, {
    String? name,
    String? kind,
    String? icon,
  }) async {
    final response = await _client.dio.patch(
      '/households/$householdId/locations/$locationId',
      data: {
        if (name != null) 'name': name,
        if (kind != null) 'kind': kind,
        if (icon != null) 'icon': icon,
      },
    );
    return StorageLocation.fromJson(response.data['location'] as Map<String, dynamic>);
  }

  /// 409 durumunda backend `itemCount` döner — çağıran taraf bunu
  /// `DioException.response.data['itemCount']` üzerinden okuyup kullanıcıya
  /// "taşı" seçeneği sunmalı.
  Future<void> deleteLocation(
    String householdId,
    String locationId, {
    String? strategy,
    String? targetLocationId,
  }) async {
    await _client.dio.delete(
      '/households/$householdId/locations/$locationId',
      queryParameters: {
        if (strategy != null) 'strategy': strategy,
        if (targetLocationId != null) 'targetLocationId': targetLocationId,
      },
    );
  }

  /// Alanın kalıcı davet kodu — backend idempotent (aktif paylaşımlı kod
  /// varsa onu döner), bu yüzden dialog her açıldığında güvenle çağrılabilir.
  /// expiresInDays: null = süresiz.
  Future<String> createInvite(String householdId, {int? expiresInDays}) async {
    final response = await _client.dio.post(
      '/households/$householdId/invites',
      data: {if (expiresInDays != null) 'expiresInDays': expiresInDays},
    );
    return response.data['invite']['code'] as String;
  }

  /// Eski kodu iptal edip yenisini üretir ("Kodu yenile").
  Future<String> rotateInvite(String householdId, {int? expiresInDays}) async {
    final response = await _client.dio.post(
      '/households/$householdId/invites/rotate',
      data: {if (expiresInDays != null) 'expiresInDays': expiresInDays},
    );
    return response.data['invite']['code'] as String;
  }

  Future<void> acceptInvite(String code) async {
    await _client.dio.post('/invites/$code/accept');
  }

  Future<List<HouseholdMember>> listMembers(String householdId) async {
    final response = await _client.dio.get('/households/$householdId/members');
    final members = response.data['members'] as List;
    return members.map((m) => HouseholdMember.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<void> leaveHousehold(String householdId) async {
    await _client.dio.delete('/households/$householdId/members/me');
  }

  Future<void> deleteHousehold(String householdId) async {
    await _client.dio.delete('/households/$householdId');
  }
}

class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.displayName,
    required this.email,
  });

  final String userId;
  final String role;
  final DateTime joinedAt;
  final String displayName;
  final String email;

  factory HouseholdMember.fromJson(Map<String, dynamic> json) => HouseholdMember(
        userId: json['userId'] as String,
        role: json['role'] as String,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        displayName: json['displayName'] as String,
        email: json['email'] as String,
      );
}
