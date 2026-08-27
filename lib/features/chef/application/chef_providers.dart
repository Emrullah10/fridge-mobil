import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../auth/application/auth_providers.dart';
import '../data/chef_repository.dart';

final chefRepositoryProvider = Provider<ChefRepository>((ref) {
  return ChefRepository(ref.watch(apiClientProvider));
});

/// Sohbet geçmişi + gönderilmemiş yerel durum tek yerde. StateNotifier
/// kullanılıyor çünkü mesaj listesi optimistic olarak güncelleniyor
/// (kullanıcı mesajı hemen görünür, cevap gelince eklenir).
class ChefChatState {
  const ChefChatState({
    this.messages = const [],
    this.loading = false,
    this.sending = false,
    this.pendingSuggestions = const [],
    this.error,
  });

  final List<ChefMessage> messages;
  final bool loading;
  final bool sending;
  final List<ChefShoppingSuggestion> pendingSuggestions;
  final String? error;

  ChefChatState copyWith({
    List<ChefMessage>? messages,
    bool? loading,
    bool? sending,
    List<ChefShoppingSuggestion>? pendingSuggestions,
    String? error,
    bool clearError = false,
  }) {
    return ChefChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      pendingSuggestions: pendingSuggestions ?? this.pendingSuggestions,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChefChatNotifier extends StateNotifier<ChefChatState> {
  ChefChatNotifier(this._repo, this._householdId) : super(const ChefChatState()) {
    load();
  }

  final ChefRepository _repo;
  final String _householdId;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final messages = await _repo.history(_householdId);
      state = state.copyWith(messages: messages, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: describeApiError(e));
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    // Optimistic: kullanıcı mesajını hemen göster.
    final optimistic = ChefMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
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

    try {
      final reply = await _repo.send(_householdId, trimmed);
      state = state.copyWith(
        messages: [...state.messages, reply.message],
        sending: false,
        pendingSuggestions: reply.suggestions,
      );
    } catch (e) {
      // Başarısızsa optimistic mesajı geri al.
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        sending: false,
        error: describeApiError(e),
      );
    }
  }

  void dismissSuggestions() => state = state.copyWith(pendingSuggestions: const []);

  Future<void> clear() async {
    await _repo.clear(_householdId);
    state = const ChefChatState();
  }
}

final chefChatProvider =
    StateNotifierProvider.family<ChefChatNotifier, ChefChatState, String>((ref, householdId) {
  return ChefChatNotifier(ref.watch(chefRepositoryProvider), householdId);
});
