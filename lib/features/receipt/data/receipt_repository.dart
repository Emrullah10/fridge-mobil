import '../../../core/api/api_client.dart';

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.id,
    required this.rawText,
    required this.parsedName,
    required this.parsedQuantity,
    required this.parsedUnit,
    required this.matchedProductId,
    required this.matchMethod,
    required this.confidence,
  });

  final String id;
  final String rawText;
  final String parsedName;
  final double parsedQuantity;
  final String parsedUnit;
  final String? matchedProductId;
  final String? matchMethod;
  final double? confidence;

  /// Kademe 1 (alias) veya kademe 2 (trigram) eşleşmesi varsa yüksek güven —
  /// UI'da bunlar ön-onaylı gösterilir, kullanıcı sadece göz atar.
  bool get isHighConfidence => matchMethod == 'alias' || (confidence ?? 0) >= 0.6;

  factory ReceiptLineItem.fromJson(Map<String, dynamic> json) => ReceiptLineItem(
        id: json['id'] as String,
        rawText: json['rawText'] as String,
        parsedName: json['parsedName'] as String? ?? json['rawText'] as String,
        parsedQuantity: (json['parsedQuantity'] as num?)?.toDouble() ?? 1,
        parsedUnit: json['parsedUnit'] as String? ?? 'piece',
        matchedProductId: json['matchedProductId'] as String?,
        matchMethod: json['matchMethod'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
      );
}

class ReceiptScanResult {
  const ReceiptScanResult({required this.status, required this.lineItems});
  final String status;
  final List<ReceiptLineItem> lineItems;
}

class ReceiptRepository {
  ReceiptRepository(this._client);

  final ApiClient _client;

  /// Telefonda ML Kit ile çıkarılan ham metni gönderir — backend'de OCR
  /// (kademe 1) atlanır, sadece Ollama anlamlandırması (kademe 2) çalışır.
  Future<String> uploadScanText(String householdId, String rawText) async {
    final response = await _client.dio.post(
      '/households/$householdId/receipts/scan-text',
      data: {'rawText': rawText},
    );
    return response.data['scanId'] as String;
  }

  Future<ReceiptScanResult> getScan(String householdId, String scanId) async {
    final response = await _client.dio.get('/households/$householdId/receipts/$scanId');
    final scan = response.data['scan'] as Map<String, dynamic>;
    final items = response.data['lineItems'] as List;
    return ReceiptScanResult(
      status: scan['status'] as String,
      lineItems: items.map((i) => ReceiptLineItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> correctLineItem(
    String householdId,
    String scanId,
    String itemId, {
    required String parsedName,
    required double parsedQuantity,
    required String parsedUnit,
  }) async {
    await _client.dio.patch(
      '/households/$householdId/receipts/$scanId/items/$itemId',
      data: {
        'parsedName': parsedName,
        'parsedQuantity': parsedQuantity,
        'parsedUnit': parsedUnit,
      },
    );
  }

  Future<void> confirm(
    String householdId,
    String scanId, {
    required String storageLocationId,
    required List<String> lineItemIds,
  }) async {
    await _client.dio.post(
      '/households/$householdId/receipts/$scanId/confirm',
      data: {
        'storageLocationId': storageLocationId,
        'itemSelections': lineItemIds.map((id) => {'lineItemId': id}).toList(),
      },
    );
  }
}
