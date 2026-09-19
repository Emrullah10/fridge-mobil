import '../../../core/api/api_client.dart';

/// chef_repository.dart'ın genellemesi (AI Chef -> AI Asistan, bkz. plan
/// §D1). Sohbetler artık kullanıcıya ait ve conversation kavramı var.
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.householdId,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? title;
  final String? householdId;
  final String mode; // 'food' | 'repair' | 'general'
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    title: json['title'] as String?,
    householdId: json['householdId'] as String?,
    mode: json['mode'] as String? ?? 'general',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Conversation copyWith({String? title, String? householdId, String? mode}) =>
      Conversation(
        id: id,
        title: title ?? this.title,
        householdId: householdId ?? this.householdId,
        mode: mode ?? this.mode,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

/// Kılavuz adımı — backend'de recipe.steps JSONB formatıyla BİREBİR aynı
/// (bkz. plan §B3) — RecipeStep.fromJson ile aynı şekli paylaşır.
class GuideStep {
  const GuideStep({required this.order, required this.text, this.minutes});
  final int order;
  final String text;
  final int? minutes;

  factory GuideStep.fromJson(Map<String, dynamic> json) => GuideStep(
    order: json['order'] as int,
    text: json['text'] as String,
    minutes: json['minutes'] as int?,
  );
}

class GuideMaterial {
  const GuideMaterial({
    required this.name,
    this.quantity,
    this.unit,
    this.isOptional = false,
  });
  final String name;
  final double? quantity;
  final String? unit;
  final bool isOptional;

  factory GuideMaterial.fromJson(Map<String, dynamic> json) => GuideMaterial(
    name: json['name'] as String,
    quantity: json['quantity'] != null
        ? (json['quantity'] as num).toDouble()
        : null,
    unit: json['unit'] as String?,
    isOptional: json['isOptional'] as bool? ?? false,
  );
}

/// AI'ın ürettiği adım adım kılavuz — "Tarife kaydet" ile recipe'ye dönüşür
/// (bkz. plan §B3, §C6).
class AssistantGuide {
  const AssistantGuide({
    required this.kind,
    required this.title,
    this.servings,
    this.prepMinutes,
    this.cookMinutes,
    required this.materials,
    required this.steps,
  });

  final String kind; // 'food' | 'task'
  final String title;
  final int? servings;
  final int? prepMinutes;
  final int? cookMinutes;
  final List<GuideMaterial> materials;
  final List<GuideStep> steps;

  factory AssistantGuide.fromJson(Map<String, dynamic> json) =>
      AssistantGuide(
        kind: json['kind'] as String? ?? 'task',
        title: json['title'] as String,
        servings: json['servings'] as int?,
        prepMinutes: json['prepMinutes'] as int?,
        cookMinutes: json['cookMinutes'] as int?,
        materials:
            (json['materials'] as List?)
                ?.map((m) => GuideMaterial.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        steps:
            (json['steps'] as List?)
                ?.map((s) => GuideStep.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.suggestedShoppingItems = const [],
    this.modeMismatch,
    this.guide,
  });

  final String id;
  final String conversationId;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;
  final List<AssistantShoppingSuggestion> suggestedShoppingItems;

  /// meta'da saklı — sohbete geri dönünce de görünür (bkz. plan §D5).
  final String? modeMismatch;
  final AssistantGuide? guide;

  bool get isUser => role == 'user';

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>?;
    return AssistantMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String? ?? '',
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      suggestedShoppingItems:
          (meta?['suggestedShoppingItems'] as List?)
              ?.map(
                (s) => AssistantShoppingSuggestion.fromJson(
                  s as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      modeMismatch: meta?['modeMismatch'] as String?,
      guide: meta?['guide'] != null
          ? AssistantGuide.fromJson(meta!['guide'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Modelin "şunu da alman lazım" önerisi. Doğrudan listeye yazılmaz —
/// kullanıcı çipe basınca eklenir (halüsinasyon savunması).
class AssistantShoppingSuggestion {
  const AssistantShoppingSuggestion({
    required this.name,
    this.quantity,
    this.unit,
    required this.reasonText,
  });

  final String name;
  final double? quantity;
  final String? unit;
  final String reasonText;

  factory AssistantShoppingSuggestion.fromJson(Map<String, dynamic> json) =>
      AssistantShoppingSuggestion(
        name: json['name'] as String,
        quantity: json['quantity'] != null
            ? (json['quantity'] as num).toDouble()
            : null,
        unit: json['unit'] as String?,
        reasonText: json['reasonText'] as String? ?? '',
      );
}

class AssistantReply {
  const AssistantReply({
    required this.message,
    required this.conversation,
    required this.suggestions,
    this.modeMismatch,
    this.guide,
  });
  final AssistantMessage message;
  final Conversation conversation;
  final List<AssistantShoppingSuggestion> suggestions;
  final String? modeMismatch;
  final AssistantGuide? guide;
}

/// KÖK SEVİYEDE mount edilir (household ağacının DIŞINDA, bkz. plan §C2) —
/// alansız sohbette householdId yok.
class AssistantRepository {
  AssistantRepository(this._client);

  final ApiClient _client;

  Future<List<Conversation>> listConversations() async {
    final response = await _client.dio.get('/assistant/conversations');
    return (response.data['conversations'] as List)
        .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<Conversation> createConversation({
    String? householdId,
    String mode = 'general',
  }) async {
    final response = await _client.dio.post(
      '/assistant/conversations',
      data: {if (householdId != null) 'householdId': householdId, 'mode': mode},
    );
    return Conversation.fromJson(
      response.data['conversation'] as Map<String, dynamic>,
    );
  }

  Future<Conversation> updateConversation(
    String id, {
    String? title,
    String? householdId,
    String? mode,
  }) async {
    final response = await _client.dio.patch(
      '/assistant/conversations/$id',
      data: {
        if (title != null) 'title': title,
        'householdId': householdId,
        if (mode != null) 'mode': mode,
      },
    );
    return Conversation.fromJson(
      response.data['conversation'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteConversation(String id) async {
    await _client.dio.delete('/assistant/conversations/$id');
  }

  Future<List<AssistantMessage>> history(String conversationId) async {
    final response = await _client.dio.get(
      '/assistant/conversations/$conversationId/messages',
    );
    return (response.data['messages'] as List)
        .map((m) => AssistantMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<AssistantReply> send(String conversationId, String message) async {
    final response = await _client.dio.post(
      '/assistant/conversations/$conversationId/messages',
      data: {'message': message},
    );
    final data = response.data as Map<String, dynamic>;
    return AssistantReply(
      message: AssistantMessage.fromJson(
        data['message'] as Map<String, dynamic>,
      ),
      conversation: Conversation.fromJson(
        data['conversation'] as Map<String, dynamic>,
      ),
      suggestions: (data['suggestedShoppingItems'] as List? ?? [])
          .map(
            (s) => AssistantShoppingSuggestion.fromJson(
              s as Map<String, dynamic>,
            ),
          )
          .toList(),
      modeMismatch: data['modeMismatch'] as String?,
      guide: data['guide'] != null
          ? AssistantGuide.fromJson(data['guide'] as Map<String, dynamic>)
          : null,
    );
  }

  /// AI çağırmaz (§C4) — guide zaten mesajın meta'sında saklı.
  Future<void> saveGuideAsRecipe(String messageId, {String? householdId}) async {
    await _client.dio.post(
      '/assistant/messages/$messageId/save-guide',
      data: {if (householdId != null) 'householdId': householdId},
    );
  }
}
