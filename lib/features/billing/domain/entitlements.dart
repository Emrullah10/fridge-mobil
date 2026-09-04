/// Backend GET /api/me/entitlements'ın Dart karşılığı — mobilin TEK
/// doğruluk kaynağı (bkz. plan §Mimari ilke). Hiçbir limit sabiti mobil
/// tarafta tutulmaz; bu model doğrudan sunucudan gelen JSON'ı taşır.
class AiQuota {
  const AiQuota({
    required this.limit,
    required this.used,
    required this.boosted,
    this.resetsAt,
  });

  /// null = sınırsız (suistimal tavanı olsa bile UI'da "sınırsız" gösterilir).
  final int? limit;
  final int used;
  final bool boosted;
  final DateTime? resetsAt;

  bool get isUnlimited => limit == null;
  bool get isExhausted => !isUnlimited && used >= limit!;
  double get usageRatio => isUnlimited || limit == 0 ? 0 : used / limit!;

  factory AiQuota.fromJson(Map<String, dynamic> json) => AiQuota(
        limit: (json['limit'] as num?)?.toInt(),
        used: (json['used'] as num?)?.toInt() ?? 0,
        boosted: json['boosted'] as bool? ?? false,
        resetsAt: json['resetsAt'] is String ? DateTime.tryParse(json['resetsAt'] as String) : null,
      );
}

class HouseholdLimits {
  const HouseholdLimits({
    required this.ownerPlan,
    this.maxMembers,
    this.maxLocations,
    this.insightsWindowDays,
  });

  final String ownerPlan;
  final int? maxMembers;
  final int? maxLocations;
  final int? insightsWindowDays;

  factory HouseholdLimits.fromJson(Map<String, dynamic> json) => HouseholdLimits(
        ownerPlan: json['ownerPlan'] as String? ?? 'free',
        maxMembers: (json['maxMembers'] as num?)?.toInt(),
        maxLocations: (json['maxLocations'] as num?)?.toInt(),
        insightsWindowDays: (json['insightsWindowDays'] as num?)?.toInt(),
      );
}

/// Kullanıcı bir aile koltuğundaysa dolu gelir — abonelik ekranında/paywall'da
/// "X'in aile paketindesin" rozeti için. source zaten 'family' oluyor ama
/// sponsor adı/alanı UI metni için ayrıca taşınır (bkz. entitlements.js
/// backend karşılığı).
class FamilySeat {
  const FamilySeat({required this.sponsorUserId, this.sponsorName, required this.householdId});

  final String sponsorUserId;
  final String? sponsorName;
  final String householdId;

  factory FamilySeat.fromJson(Map<String, dynamic> json) => FamilySeat(
        sponsorUserId: json['sponsorUserId'] as String,
        sponsorName: json['sponsorName'] as String?,
        householdId: json['householdId'] as String,
      );
}

/// Abonelik ekranındaki koltuk roster'ı — SADECE kullanıcı kendisi bir aile
/// aboneliğinin sahibiyse dolu gelir ("Aile üyeleri 3/5").
class FamilySeatMember {
  const FamilySeatMember({required this.userId, this.displayName, required this.householdId, required this.active});

  final String userId;
  final String? displayName;
  final String householdId;
  final bool active;

  factory FamilySeatMember.fromJson(Map<String, dynamic> json) => FamilySeatMember(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String?,
        householdId: json['householdId'] as String,
        active: json['active'] as bool? ?? false,
      );
}

class FamilyRoster {
  const FamilyRoster({required this.seats, required this.used, required this.members});

  final int seats;
  final int used;
  final List<FamilySeatMember> members;

  factory FamilyRoster.fromJson(Map<String, dynamic> json) => FamilyRoster(
        seats: (json['seats'] as num?)?.toInt() ?? 0,
        used: (json['used'] as num?)?.toInt() ?? 0,
        members: (json['members'] as List<dynamic>? ?? const [])
            .map((m) => FamilySeatMember.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

/// plan: guest | free | trial | premium
enum PlanTier { guest, free, trial, premium }

PlanTier _planTierFrom(String? value) {
  switch (value) {
    case 'guest':
      return PlanTier.guest;
    case 'trial':
      return PlanTier.trial;
    case 'premium':
      return PlanTier.premium;
    default:
      return PlanTier.free;
  }
}

class Entitlements {
  const Entitlements({
    required this.plan,
    required this.source,
    required this.status,
    required this.features,
    required this.quotas,
    required this.households,
    this.trialEndsAt,
    this.periodEndsAt,
    this.familySeat,
    this.family,
  });

  final PlanTier plan;
  final String source;
  final String status;
  final Map<String, bool> features;
  final Map<String, AiQuota> quotas;
  final Map<String, HouseholdLimits> households;
  final DateTime? trialEndsAt;
  final DateTime? periodEndsAt;
  final FamilySeat? familySeat;
  final FamilyRoster? family;

  bool get isGuest => plan == PlanTier.guest;
  bool get isPremium => plan == PlanTier.premium;
  bool get isTrial => plan == PlanTier.trial;
  bool get isFamilySponsor => family != null;
  bool get isFamilyMember => familySeat != null;

  AiQuota? quotaFor(String feature) => quotas[feature];

  /// Deneme ekranlarında "kaç gün kaldı" göstermek için — negatifse (deneme
  /// bitmiş) sıfıra kırpılır, UI ekstra kontrol yazmasın diye.
  int? get trialDaysLeft {
    if (trialEndsAt == null) return null;
    final diff = trialEndsAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    final quotasJson = json['quotas'] as Map<String, dynamic>? ?? const {};
    final householdsJson = json['households'] as Map<String, dynamic>? ?? const {};
    final featuresJson = json['features'] as Map<String, dynamic>? ?? const {};
    final familySeatJson = json['familySeat'] as Map<String, dynamic>?;
    final familyJson = json['family'] as Map<String, dynamic>?;
    return Entitlements(
      plan: _planTierFrom(json['plan'] as String?),
      source: json['source'] as String? ?? 'signup',
      status: json['status'] as String? ?? 'active',
      features: featuresJson.map((key, value) => MapEntry(key, value as bool? ?? false)),
      quotas: quotasJson.map((key, value) => MapEntry(key, AiQuota.fromJson(value as Map<String, dynamic>))),
      households: householdsJson.map((key, value) => MapEntry(key, HouseholdLimits.fromJson(value as Map<String, dynamic>))),
      trialEndsAt: json['trialEndsAt'] is String ? DateTime.tryParse(json['trialEndsAt'] as String) : null,
      periodEndsAt: json['periodEndsAt'] is String ? DateTime.tryParse(json['periodEndsAt'] as String) : null,
      familySeat: familySeatJson != null ? FamilySeat.fromJson(familySeatJson) : null,
      family: familyJson != null ? FamilyRoster.fromJson(familyJson) : null,
    );
  }

  /// Oturum açılmadan/henüz yüklenmeden önceki güvenli varsayılan — hiçbir
  /// şeye izin vermez, UI "yükleniyor" durumuyla aynı şekilde ele alabilir.
  static const Entitlements empty = Entitlements(
    plan: PlanTier.guest,
    source: 'signup',
    status: 'active',
    features: {},
    quotas: {},
    households: {},
  );
}
