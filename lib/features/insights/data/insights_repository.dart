import '../../../core/api/api_client.dart';

/// Para & israf paneli verisi. Backend: GET /households/:id/insights
class HouseholdInsights {
  const HouseholdInsights({
    required this.periodFrom,
    required this.periodTo,
    required this.saved,
    required this.wasted,
    required this.spent,
    required this.missingPriceCount,
    required this.byCategory,
    required this.byMember,
    required this.topWasted,
  });

  final DateTime periodFrom;
  final DateTime periodTo;

  /// Zamanında kullanılan ürünlerin toplam değeri ("kurtarılan para").
  final double saved;

  /// Bozulan / son kullanma tarihi geçen ürünlerin toplam değeri ("israf").
  final double wasted;

  /// Dönem içinde fişten envantere giren ürünlerin toplam değeri.
  final double spent;

  /// Fiyatı bilinmediği için toplamlara katılmayan hareket sayısı.
  final int missingPriceCount;

  final List<InsightBucket> byCategory;
  final List<InsightMember> byMember;
  final List<WastedProduct> topWasted;

  factory HouseholdInsights.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    return HouseholdInsights(
      periodFrom: DateTime.parse(period['from'] as String),
      periodTo: DateTime.parse(period['to'] as String),
      saved: (json['saved'] as num).toDouble(),
      wasted: (json['wasted'] as num).toDouble(),
      spent: (json['spent'] as num).toDouble(),
      missingPriceCount: (json['missingPriceCount'] as num?)?.toInt() ?? 0,
      byCategory: (json['byCategory'] as List? ?? [])
          .map((e) => InsightBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
      byMember: (json['byMember'] as List? ?? [])
          .map((e) => InsightMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      topWasted: (json['topWasted'] as List? ?? [])
          .map((e) => WastedProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InsightBucket {
  const InsightBucket({required this.categoryKey, required this.saved, required this.wasted});
  final String categoryKey;
  final double saved;
  final double wasted;

  factory InsightBucket.fromJson(Map<String, dynamic> json) => InsightBucket(
        categoryKey: json['categoryKey'] as String? ?? 'uncategorized',
        saved: (json['saved'] as num).toDouble(),
        wasted: (json['wasted'] as num).toDouble(),
      );
}

class InsightMember {
  const InsightMember({required this.userId, required this.displayName, required this.saved, required this.wasted});
  final String? userId;
  final String? displayName;
  final double saved;
  final double wasted;

  factory InsightMember.fromJson(Map<String, dynamic> json) => InsightMember(
        userId: json['userId'] as String?,
        displayName: json['displayName'] as String?,
        saved: (json['saved'] as num).toDouble(),
        wasted: (json['wasted'] as num).toDouble(),
      );
}

class WastedProduct {
  const WastedProduct({required this.productName, required this.productBrand, required this.wasted, required this.quantity});
  final String? productName;
  final String? productBrand;
  final double wasted;
  final double quantity;

  factory WastedProduct.fromJson(Map<String, dynamic> json) => WastedProduct(
        productName: json['productName'] as String?,
        productBrand: json['productBrand'] as String?,
        wasted: (json['wasted'] as num).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
      );
}

class InsightsRepository {
  InsightsRepository(this._client);

  final ApiClient _client;

  /// [from]/[to] verilmezse backend içinde bulunulan takvim ayını kullanır.
  Future<HouseholdInsights> fetch(String householdId, {DateTime? from, DateTime? to}) async {
    final response = await _client.dio.get(
      '/households/$householdId/insights',
      queryParameters: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
    );
    return HouseholdInsights.fromJson(response.data as Map<String, dynamic>);
  }
}
