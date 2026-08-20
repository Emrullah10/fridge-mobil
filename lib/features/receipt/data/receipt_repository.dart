import '../../../core/api/api_client.dart';

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.id,
    required this.rawText,
    required this.parsedName,
    this.parsedBrand,
    required this.parsedQuantity,
    required this.parsedUnit,
    required this.matchedProductId,
    required this.matchMethod,
    required this.confidence,
    this.suggestedStorageKind,
  });

  final String id;
  final String rawText;
  final String parsedName;
  final String? parsedBrand;
  final double parsedQuantity;
  final String parsedUnit;
  final String? matchedProductId;
  final String? matchMethod;
  final double? confidence;

  /// Backend'in eşleşen ürünün kategorisinden (ya da anahtar kelime
  /// yedeğinden) türettiği bölüm önerisi: 'fridge' | 'freezer' | 'pantry'.
  /// null ise kategori belirsiz — kullanıcı elle seçmeli.
  final String? suggestedStorageKind;

  /// Kademe 1 (alias) veya kademe 2 (trigram, yüksek benzerlik) eşleşmesi
  /// varsa yüksek güven — UI'da bunlar ön-onaylı gösterilir. AI'ın otomatik
  /// oluşturduğu ürünler (matchMethod: 'model') her zaman düşük güven sayılır
  /// — kimse doğrulamadı, kullanıcının göz atması gerekir.
  bool get isHighConfidence =>
      matchedProductId != null && (matchMethod == 'alias' || (matchMethod == 'trigram' && (confidence ?? 0) >= 0.6));

  factory ReceiptLineItem.fromJson(Map<String, dynamic> json) => ReceiptLineItem(
        id: json['id'] as String,
        rawText: json['rawText'] as String,
        parsedName: json['parsedName'] as String? ?? json['rawText'] as String,
        parsedBrand: json['parsedBrand'] as String?,
        parsedQuantity: (json['parsedQuantity'] as num?)?.toDouble() ?? 1,
        parsedUnit: json['parsedUnit'] as String? ?? 'piece',
        matchedProductId: json['matchedProductId'] as String?,
        matchMethod: json['matchMethod'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        suggestedStorageKind: json['suggestedStorageKind'] as String?,
      );
}

class ReceiptScanResult {
  const ReceiptScanResult({required this.status, required this.lineItems});
  final String status;
  final List<ReceiptLineItem> lineItems;
}

class ReceiptScanSummary {
  const ReceiptScanSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    this.merchantName,
    this.totalAmount,
    this.errorMessage,
  });

  final String id;
  final String status;
  final DateTime createdAt;
  final String? merchantName;
  final double? totalAmount;
  final String? errorMessage;

  factory ReceiptScanSummary.fromJson(Map<String, dynamic> json) => ReceiptScanSummary(
        id: json['id'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        merchantName: json['merchantName'] as String?,
        totalAmount: (json['totalAmount'] as num?)?.toDouble(),
        errorMessage: json['errorMessage'] as String?,
      );
}

class ReceiptRepository {
  ReceiptRepository(this._client);

  final ApiClient _client;

  /// Fiş geçmişi: household'a ait tüm taramalar, en yeniden eskiye.
  Future<List<ReceiptScanSummary>> listScans(String householdId) async {
    final response = await _client.dio.get('/households/$householdId/receipts');
    final scans = response.data['scans'] as List;
    return scans.map((s) => ReceiptScanSummary.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<void> retry(String householdId, String scanId) async {
    await _client.dio.post('/households/$householdId/receipts/$scanId/retry');
  }

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
    String? parsedBrand,
    required double parsedQuantity,
    required String parsedUnit,
    required String matchedProductId,
  }) async {
    await _client.dio.patch(
      '/households/$householdId/receipts/$scanId/items/$itemId',
      data: {
        'parsedName': parsedName,
        'parsedBrand': ?parsedBrand,
        'parsedQuantity': parsedQuantity,
        'parsedUnit': parsedUnit,
        'matchedProductId': matchedProductId,
      },
    );
  }

  /// itemSelections her satır için matchedProductId taşır — backend bunu
  /// zorunlu tutuyor (confirm-receipt-scan.use-case.js), çünkü hangi ürüne
  /// hangi miktarın ekleneceğini garanti eden tek bilgi bu. storageLocationId
  /// da satır bazında gönderilir — her ürün kendi önerilen/seçilen bölümüne
  /// gider (backend bunu zaten destekliyor, sadece mobil hiç kullanmıyordu).
  Future<void> confirm(
    String householdId,
    String scanId, {
    required Map<String, String> locationIdByItemId,
    required List<ReceiptLineItem> items,
    Map<String, DateTime?> expiresAtByItemId = const {},
  }) async {
    await _client.dio.post(
      '/households/$householdId/receipts/$scanId/confirm',
      data: {
        'itemSelections': items
            .map((item) => {
                  'lineItemId': item.id,
                  'matchedProductId': item.matchedProductId,
                  'storageLocationId': locationIdByItemId[item.id],
                  if (expiresAtByItemId[item.id] != null)
                    'expiresAt': expiresAtByItemId[item.id]!.toIso8601String(),
                })
            .toList(),
      },
    );
  }
}
