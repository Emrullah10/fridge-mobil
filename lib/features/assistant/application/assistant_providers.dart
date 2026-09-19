import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../auth/application/auth_providers.dart';
import '../data/assistant_repository.dart';

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepository(ref.watch(apiClientProvider));
});

/// chef_providers.dart'taki ChefChatNotifier ikiye bölündü (bkz. plan §D4):
///  - conversationListProvider: çekmece listesi, kullanıcı bazlı, family
///    DEĞİL.
///  - conversationChatProvider: tek bir sohbetin mesajları, family<..,
///    String conversationId>.
///  - activeConversationIdProvider: şu an açık olan sohbetin id'si
///    (null = henüz yaratılmamış "Yeni sohbet").
class ConversationListNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    return ref.watch(assistantRepositoryProvider).listConversations();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(assistantRepositoryProvider).listConversations(),
    );
  }

  Future<void> remove(String id) async {
    await ref.read(assistantRepositoryProvider).deleteConversation(id);
    await refresh();
  }

  Future<void> rename(String id, String title) async {
    await ref.read(assistantRepositoryProvider).updateConversation(
      id,
      title: title,
    );
    await refresh();
  }
}

final conversationListProvider =
    AsyncNotifierProvider<ConversationListNotifier, List<Conversation>>(
      ConversationListNotifier.new,
    );

/// Şu an açık sohbetin id'si. null = "Yeni sohbet" seçili ama HENÜZ
/// backend'de yaratılmadı (bkz. plan §D4 "Henüz yaratılmamış sohbet") — ilk
/// mesajda send() önce POST /conversations sonra POST /messages atar.
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

class ConversationChatState {
  const ConversationChatState({
    this.conversation,
    this.messages = const [],
    this.loading = false,
    this.sending = false,
    this.pendingSuggestions = const [],
    this.error,
    this.planLimitInfo,
  });

  final Conversation? conversation;
  final List<AssistantMessage> messages;
  final bool loading;
  final bool sending;
  final List<AssistantShoppingSuggestion> pendingSuggestions;
  final String? error;

  /// 402 (misafir/kota dolu) geldiğinde dolar — ekran bunu görünce metin
  /// hatası yerine paywall gösterir.
  final PlanLimitInfo? planLimitInfo;

  ConversationChatState copyWith({
    Conversation? conversation,
    List<AssistantMessage>? messages,
    bool? loading,
    bool? sending,
    List<AssistantShoppingSuggestion>? pendingSuggestions,
    String? error,
    bool clearError = false,
    PlanLimitInfo? planLimitInfo,
    bool clearPlanLimitInfo = false,
  }) {
    return ConversationChatState(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      pendingSuggestions: pendingSuggestions ?? this.pendingSuggestions,
      error: clearError ? null : (error ?? this.error),
      planLimitInfo: clearPlanLimitInfo
          ? null
          : (planLimitInfo ?? this.planLimitInfo),
    );
  }
}

/// family<ConversationChatNotifier, ConversationChatState, String?> —
/// conversationId null olabilir ("Yeni sohbet", henüz yaratılmadı). Riverpod
/// family null anahtarı destekler.
class ConversationChatNotifier
    extends StateNotifier<ConversationChatState> {
  ConversationChatNotifier(this._ref, this._repo, this._conversationId)
    : super(const ConversationChatState()) {
    if (_conversationId != null) load();
  }

  final Ref _ref;
  final AssistantRepository _repo;
  final String? _conversationId;

  Future<void> load() async {
    if (_conversationId == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final messages = await _repo.history(_conversationId);
      state = state.copyWith(messages: messages, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: describeApiError(e));
    }
  }

  /// initialHouseholdId/initialMode: yalnızca sohbet HENÜZ yaratılmamışsa
  /// (conversationId == null) ilk POST /conversations'ta kullanılır.
  Future<void> send(
    String text, {
    String? initialHouseholdId,
    String initialMode = 'general',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    final optimistic = AssistantMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: _conversationId ?? '',
      role: 'user',
      content: trimmed,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      sending: true,
      pendingSuggestions: const [],
      clearError: true,
    );

    String? conversationId = _conversationId;
    try {
      // Henüz yaratılmamış sohbet: ilk mesajda önce POST /conversations,
      // dönen id hem burada hem activeConversationIdProvider'a yazılır
      // (bkz. plan §D4 uyarısı — kota 402'si burada gelirse boş conversation
      // kalır, kabul edilebilir).
      if (conversationId == null) {
        final created = await _repo.createConversation(
          householdId: initialHouseholdId,
          mode: initialMode,
        );
        conversationId = created.id;
        state = state.copyWith(conversation: created);
        _ref.read(activeConversationIdProvider.notifier).state = conversationId;
      }

      final reply = await _repo.send(conversationId, trimmed);
      state = state.copyWith(
        conversation: reply.conversation,
        messages: [...state.messages, reply.message],
        sending: false,
        pendingSuggestions: reply.suggestions,
        clearPlanLimitInfo: true,
      );
      _ref.read(conversationListProvider.notifier).refresh();
    } catch (e) {
      final planLimitInfo = PlanLimitInfo.tryParse(e);
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        sending: false,
        error: planLimitInfo == null ? describeApiError(e) : null,
        planLimitInfo: planLimitInfo,
      );
    }
  }

  Future<void> changeMode(String mode) async {
    if (_conversationId == null) return;
    try {
      final updated = await _repo.updateConversation(
        _conversationId,
        mode: mode,
      );
      state = state.copyWith(conversation: updated);
      _ref.read(conversationListProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(error: describeApiError(e));
    }
  }

  Future<void> saveGuideAsRecipe(String messageId, {String? householdId}) =>
      _repo.saveGuideAsRecipe(messageId, householdId: householdId);

  void dismissPlanLimitInfo() =>
      state = state.copyWith(clearPlanLimitInfo: true);

  void dismissSuggestions() =>
      state = state.copyWith(pendingSuggestions: const []);
}

final conversationChatProvider = StateNotifierProvider.family<
    ConversationChatNotifier, ConversationChatState, String?>((ref, conversationId) {
  return ConversationChatNotifier(
    ref,
    ref.watch(assistantRepositoryProvider),
    conversationId,
  );
});
