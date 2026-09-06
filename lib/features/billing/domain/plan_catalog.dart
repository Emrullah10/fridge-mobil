/// Backend GET /api/plans'ın Dart karşılığı — entitlements.dart'taki ilkeyle
/// aynı (bkz. plan §Mimari ilke): hiçbir limit sabiti mobilde tutulmaz, bu
/// model doğrudan sunucudan gelen JSON'ı taşır. entitlements.dart'ın aksine
/// BELİRLİ bir kullanıcıya değil, TÜM planlara bakar — "Ücretsiz vs Premium"
/// karşılaştırma kartı bunu kullanır.
class PlanLimits {
  const PlanLimits({
    required this.aiReceipt,
    required this.aiRecipe,
    required this.aiChef,
    required this.aiShopping,
    required this.householdCount,
    required this.locationPerHousehold,
    required this.memberPerHousehold,
    required this.insightsWindowDays,
    required this.barcode,
    required this.export,
  });

  /// null = sınırsız — UI "Sınırsız" gösterir (entitlements.dart'taki
  /// AiQuota.isUnlimited ile aynı sözleşme).
  final int? aiReceipt;
  final int? aiRecipe;
  final int? aiChef;
  final int? aiShopping;
  final int? householdCount;
  final int? locationPerHousehold;
  final int? memberPerHousehold;
  final int? insightsWindowDays;
  final bool barcode;
  final bool export;

  factory PlanLimits.fromJson(Map<String, dynamic> json) {
    final ai = json['ai'] as Map<String, dynamic>? ?? const {};
    final household = json['household'] as Map<String, dynamic>? ?? const {};
    final location = json['location'] as Map<String, dynamic>? ?? const {};
    final member = json['member'] as Map<String, dynamic>? ?? const {};
    final insights = json['insights'] as Map<String, dynamic>? ?? const {};
    final features = json['features'] as Map<String, dynamic>? ?? const {};
    return PlanLimits(
      aiReceipt: (ai['receipt'] as num?)?.toInt(),
      aiRecipe: (ai['recipe'] as num?)?.toInt(),
      aiChef: (ai['chef'] as num?)?.toInt(),
      aiShopping: (ai['shopping'] as num?)?.toInt(),
      householdCount: (household['count'] as num?)?.toInt(),
      locationPerHousehold: (location['perHousehold'] as num?)?.toInt(),
      memberPerHousehold: (member['perHousehold'] as num?)?.toInt(),
      insightsWindowDays: (insights['windowDays'] as num?)?.toInt(),
      barcode: features['barcode'] as bool? ?? false,
      export: features['export'] as bool? ?? false,
    );
  }
}

class PlanCatalog {
  const PlanCatalog({required this.free, required this.premium, required this.familySeats});

  final PlanLimits free;
  final PlanLimits premium;

  /// null = aile paketi şu an satılmıyor.
  final int? familySeats;

  factory PlanCatalog.fromJson(Map<String, dynamic> json) {
    final plans = json['plans'] as Map<String, dynamic>? ?? const {};
    return PlanCatalog(
      free: PlanLimits.fromJson(plans['free'] as Map<String, dynamic>? ?? const {}),
      premium: PlanLimits.fromJson(plans['premium'] as Map<String, dynamic>? ?? const {}),
      familySeats: (json['familySeats'] as num?)?.toInt(),
    );
  }
}
