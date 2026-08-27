import '../../../core/api/api_client.dart';

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.storageLocationId,
    required this.quantity,
    required this.unit,
    this.expiresAt,
    this.unitPrice,
  });

  final String id;
  final String productId;
  final String productName;
  final String storageLocationId;
  final double quantity;
  final String unit;
  final DateTime? expiresAt;
  final double? unitPrice;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        productId: json['productId'] as String,
        productName: json['productName'] as String? ?? 'Bilinmeyen ürün',
        storageLocationId: json['storageLocationId'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String,
        expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt'] as String) : null,
        unitPrice: json['unitPrice'] != null ? (json['unitPrice'] as num).toDouble() : null,
      );
}

class InventoryRepository {
  InventoryRepository(this._client);

  final ApiClient _client;

  Future<List<InventoryItem>> listItems(String householdId, {String? storageLocationId}) async {
    final response = await _client.dio.get(
      '/households/$householdId/inventory',
      queryParameters: storageLocationId != null ? {'storageLocationId': storageLocationId} : null,
    );
    final items = response.data['items'] as List;
    return items.map((i) => InventoryItem.fromJson(i as Map<String, dynamic>)).toList();
  }

  /// [reason]: `consumed` (kullanıldı, para tasarrufu) | `expired` | `discarded`
  /// (bozuldu/atıldı, israf). Boş bırakılırsa backend `consumed` varsayar.
  Future<void> consume(
    String householdId,
    String itemId,
    double quantity, {
    String reason = 'consumed',
  }) async {
    await _client.dio.post(
      '/households/$householdId/inventory/$itemId/consume',
      data: {'quantity': quantity, 'reason': reason},
    );
  }

  /// Kalemi tamamen kaldırır. [reason]: `discarded` (varsayılan, israf) |
  /// `expired` | `consumed`.
  Future<void> deleteItem(
    String householdId,
    String itemId, {
    String reason = 'discarded',
  }) async {
    await _client.dio.delete(
      '/households/$householdId/inventory/$itemId',
      queryParameters: {'reason': reason},
    );
  }

  Future<InventoryItem> addItem(
    String householdId, {
    required String storageLocationId,
    required String productId,
    required String unit,
    required double quantity,
    DateTime? expiresAt,
    double? unitPrice,
  }) async {
    final response = await _client.dio.post(
      '/households/$householdId/inventory',
      data: {
        'storageLocationId': storageLocationId,
        'productId': productId,
        'unit': unit,
        'quantity': quantity,
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        if (unitPrice != null) 'unitPrice': unitPrice,
      },
    );
    return InventoryItem.fromJson(response.data['item'] as Map<String, dynamic>);
  }
}
