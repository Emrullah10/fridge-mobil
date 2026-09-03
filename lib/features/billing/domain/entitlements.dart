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
  });

  final PlanTier plan;
  final String source;
  final String status;
  final Map<String, bool> features;
  final Map<String, AiQuota> quotas;
  final Map<String, HouseholdLimits> households;
  final DateTime? trialEndsAt;
  final DateTime? periodEndsAt;

  bool get isGuest => plan == PlanTier.guest;
  bool get isPremium => plan == PlanTier.premium;
  bool get isTrial => plan == PlanTier.trial;

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
    return Entitlements(
      plan: _planTierFrom(json['plan'] as String?),
      source: json['source'] as String? ?? 'signup',
      status: json['status'] as String? ?? 'active',
      features: featuresJson.map((key, value) => MapEntry(key, value as bool? ?? false)),
      quotas: quotasJson.map((key, value) => MapEntry(key, AiQuota.fromJson(value as Map<String, dynamic>))),
      households: householdsJson.map((key, value) => MapEntry(key, HouseholdLimits.fromJson(value as Map<String, dynamic>))),
      trialEndsAt: json['trialEndsAt'] is String ? DateTime.tryParse(json['trialEndsAt'] as String) : null,
      periodEndsAt: json['periodEndsAt'] is String ? DateTime.tryParse(json['periodEndsAt'] as String) : null,
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
