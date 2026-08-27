import '../../../core/api/api_client.dart';

class ChefMessage {
  const ChefMessage({required this.id, required this.role, required this.content, required this.createdAt});

  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;

  bool get isUser => role == 'user';

  factory ChefMessage.fromJson(Map<String, dynamic> json) => ChefMessage(
        id: json['id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Modelin "şunu da alman lazım" önerisi. Doğrudan listeye yazılmaz —
/// kullanıcı çipe basınca eklenir (halüsinasyon savunması).
class ChefShoppingSuggestion {
  const ChefShoppingSuggestion({required this.name, this.quantity, this.unit, required this.reasonText});

  final String name;
  final double? quantity;
  final String? unit;
  final String reasonText;

  factory ChefShoppingSuggestion.fromJson(Map<String, dynamic> json) => ChefShoppingSuggestion(
        name: json['name'] as String,
        quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : null,
        unit: json['unit'] as String?,
        reasonText: json['reasonText'] as String? ?? '',
      );
}

class ChefReply {
  const ChefReply({required this.message, required this.suggestions});
  final ChefMessage message;
  final List<ChefShoppingSuggestion> suggestions;
}

class ChefRepository {
  ChefRepository(this._client);

  final ApiClient _client;

  Future<List<ChefMessage>> history(String householdId) async {
    final response = await _client.dio.get('/households/$householdId/chef/messages');
    return (response.data['messages'] as List)
        .map((m) => ChefMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<ChefReply> send(String householdId, String message) async {
    final response = await _client.dio.post(
      '/households/$householdId/chef/messages',
      data: {'message': message},
    );
    final data = response.data as Map<String, dynamic>;
    return ChefReply(
      message: ChefMessage.fromJson(data['message'] as Map<String, dynamic>),
      suggestions: (data['suggestedShoppingItems'] as List? ?? [])
          .map((s) => ChefShoppingSuggestion.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> clear(String householdId) async {
    await _client.dio.delete('/households/$householdId/chef/messages');
  }
}
