import '../../../core/api/api_client.dart';

class ShoppingList {
  const ShoppingList({required this.id, required this.name});

  final String id;
  final String name;

  factory ShoppingList.fromJson(Map<String, dynamic> json) => ShoppingList(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isChecked,
    required this.note,
    required this.source,
  });

  final String id;
  final String? productId;
  final String name;
  final double quantity;
  final String unit;
  final bool isChecked;
  final String? note;
  // 'manual' | 'recipe' | 'low_stock' | 'receipt'
  final String source;

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id'] as String,
        productId: json['productId'] as String?,
        name: json['name'] as String? ?? 'Bilinmeyen ürün',
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String,
        isChecked: json['isChecked'] as bool? ?? false,
        note: json['note'] as String?,
        source: json['source'] as String? ?? 'manual',
      );
}

class ShoppingSuggestion {
  const ShoppingSuggestion({
    required this.productId,
    required this.name,
    required this.unit,
    this.quantity,
    this.reason,
    this.reasonText,
    this.confidence,
  });

  final String? productId;
  final String name;
  final String unit;
  final double? quantity;
  // 'low_stock' | 'due_soon' | 'ran_out' | 'complementary' | 'user_request'
  final String? reason;
  final String? reasonText;
  final double? confidence;

  factory ShoppingSuggestion.fromJson(Map<String, dynamic> json) => ShoppingSuggestion(
        productId: json['productId'] as String?,
        name: json['name'] as String,
        unit: json['unit'] as String,
        quantity: (json['quantity'] as num?)?.toDouble(),
        reason: json['reason'] as String?,
        reasonText: json['reasonText'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
      );
}

class ShoppingListData {
  const ShoppingListData({required this.list, required this.items});
  final ShoppingList list;
  final List<ShoppingItem> items;
}

class ShoppingRepository {
  ShoppingRepository(this._client);

  final ApiClient _client;

  String _base(String householdId) => '/households/$householdId/shopping-list';

  Future<ShoppingListData> getList(String householdId) async {
    final response = await _client.dio.get(_base(householdId));
    return ShoppingListData(
      list: ShoppingList.fromJson(response.data['list'] as Map<String, dynamic>),
      items: (response.data['items'] as List)
          .map((i) => ShoppingItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<ShoppingSuggestion>> suggestions(String householdId) async {
    final response = await _client.dio.get('${_base(householdId)}/suggestions');
    return (response.data['suggestions'] as List)
        .map((s) => ShoppingSuggestion.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Tüketim ritmine dayalı AI önerileri. Açık kullanıcı jestiyle çağrılır,
  /// otomatik değil — her istek Gemini'ye para harcıyor.
  Future<List<ShoppingSuggestion>> aiSuggestions(String householdId) async {
    final response = await _client.dio.post('${_base(householdId)}/suggestions/ai');
    return (response.data['suggestions'] as List)
        .map((s) => ShoppingSuggestion.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Serbest metinden alışveriş önerisi ("bu hafta 4 kişilik kahvaltılık lazım").
  Future<List<ShoppingSuggestion>> suggestFromText(String householdId, String text) async {
    final response = await _client.dio.post('${_base(householdId)}/from-text', data: {'text': text});
    return (response.data['suggestions'] as List)
        .map((s) => ShoppingSuggestion.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<ShoppingItem> addItem(
    String householdId, {
    String? productId,
    String? customName,
    double quantity = 1,
    String unit = 'piece',
    String? note,
    String source = 'manual',
  }) async {
    final response = await _client.dio.post('${_base(householdId)}/items', data: {
      if (productId != null) 'productId': productId,
      if (customName != null) 'customName': customName,
      'quantity': quantity,
      'unit': unit,
      if (note != null) 'note': note,
      'source': source,
    });
    return ShoppingItem.fromJson(response.data['item'] as Map<String, dynamic>);
  }

  Future<ShoppingItem> updateItem(
    String householdId,
    String itemId, {
    double? quantity,
    String? unit,
    String? note,
    bool? isChecked,
  }) async {
    final response = await _client.dio.patch('${_base(householdId)}/items/$itemId', data: {
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (note != null) 'note': note,
      if (isChecked != null) 'isChecked': isChecked,
    });
    return ShoppingItem.fromJson(response.data['item'] as Map<String, dynamic>);
  }

  Future<void> removeItem(String householdId, String itemId) async {
    await _client.dio.delete('${_base(householdId)}/items/$itemId');
  }

  Future<void> reorder(String householdId, List<String> orderedIds) async {
    await _client.dio.post('${_base(householdId)}/items/reorder', data: {'orderedIds': orderedIds});
  }

  Future<int> clearChecked(String householdId) async {
    final response = await _client.dio.delete('${_base(householdId)}/checked');
    return response.data['removed'] as int;
  }

  Future<int> addFromRecipe(String householdId, String recipeId) async {
    final response = await _client.dio.post('${_base(householdId)}/from-recipe/$recipeId');
    return response.data['added'] as int;
  }

  Future<int> transferToInventory(
    String householdId, {
    required String storageLocationId,
    DateTime? expiresAt,
  }) async {
    final response = await _client.dio.post('${_base(householdId)}/transfer', data: {
      'storageLocationId': storageLocationId,
      if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
    });
    return response.data['transferred'] as int;
  }
}
