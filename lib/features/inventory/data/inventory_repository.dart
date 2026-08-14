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
  });

  final String id;
  final String productId;
  final String productName;
  final String storageLocationId;
  final double quantity;
  final String unit;
  final DateTime? expiresAt;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        productId: json['productId'] as String,
        productName: json['productName'] as String? ?? 'Bilinmeyen ürün',
        storageLocationId: json['storageLocationId'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String,
        expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt'] as String) : null,
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

  Future<void> consume(String householdId, String itemId, double quantity) async {
    await _client.dio.post(
      '/households/$householdId/inventory/$itemId/consume',
      data: {'quantity': quantity},
    );
  }
}
