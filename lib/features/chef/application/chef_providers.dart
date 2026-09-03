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
    this.planLimitInfo,
  });

  final List<ChefMessage> messages;
  final bool loading;
  final bool sending;
  final List<ChefShoppingSuggestion> pendingSuggestions;
  final String? error;

  /// 402 (misafir/kota dolu) geldiğinde dolar — ekran bunu görünce metin
  /// hatası yerine paywall gösterir (bkz. chef_chat_screen.dart).
  final PlanLimitInfo? planLimitInfo;

  ChefChatState copyWith({
    List<ChefMessage>? messages,
    bool? loading,
    bool? sending,
    List<ChefShoppingSuggestion>? pendingSuggestions,
    String? error,
    bool clearError = false,
    PlanLimitInfo? planLimitInfo,
    bool clearPlanLimitInfo = false,
  }) {
    return ChefChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      pendingSuggestions: pendingSuggestions ?? this.pendingSuggestions,
      error: clearError ? null : (error ?? this.error),
      planLimitInfo: clearPlanLimitInfo ? null : (planLimitInfo ?? this.planLimitInfo),
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
        clearPlanLimitInfo: true,
      );
    } catch (e) {
      // Başarısızsa optimistic mesajı geri al.
      final planLimitInfo = PlanLimitInfo.tryParse(e);
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        sending: false,
        error: planLimitInfo == null ? describeApiError(e) : null,
        planLimitInfo: planLimitInfo,
      );
    }
  }

  /// Ekran paywall'ı gösterdikten sonra çağırır — aynı hata tekrar
  /// tetiklenmesin (kullanıcı ekrandan çıkıp geri dönerse eski planLimitInfo
  /// kalıp yeniden paywall açmasın).
  void dismissPlanLimitInfo() => state = state.copyWith(clearPlanLimitInfo: true);

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
