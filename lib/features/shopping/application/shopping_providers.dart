import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/shopping_repository.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepository(ref.watch(apiClientProvider));
});

final shoppingListProvider = FutureProvider.family<ShoppingListData, String>((ref, householdId) async {
  return ref.watch(shoppingRepositoryProvider).getList(householdId);
});

final shoppingSuggestionsProvider = FutureProvider.family<List<ShoppingSuggestion>, String>((ref, householdId) async {
  return ref.watch(shoppingRepositoryProvider).suggestions(householdId);
});

/// Tüketim ritmine dayalı AI önerileri. Bilinçli olarak FutureProvider
/// DEĞİL — ekran açılışında otomatik tetiklenmemeli, her çağrı Gemini'ye
/// para harcıyor. Kullanıcı butona basınca generate() çağrılır.
class AiShoppingSuggestionsNotifier extends FamilyAsyncNotifier<List<ShoppingSuggestion>, String> {
  @override
  Future<List<ShoppingSuggestion>> build(String householdId) async => [];

  Future<void> generate() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(shoppingRepositoryProvider).aiSuggestions(arg),
    );
  }
}

final aiShoppingSuggestionsProvider =
    AsyncNotifierProvider.family<AiShoppingSuggestionsNotifier, List<ShoppingSuggestion>, String>(
  AiShoppingSuggestionsNotifier.new,
);

/// Serbest metinden alışveriş önerisi. Aynı gerekçeyle FutureProvider değil.
class TextShoppingSuggestionsNotifier extends FamilyAsyncNotifier<List<ShoppingSuggestion>, String> {
  @override
  Future<List<ShoppingSuggestion>> build(String householdId) async => [];

  Future<void> generate(String text) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(shoppingRepositoryProvider).suggestFromText(arg, text),
    );
  }
}

final textShoppingSuggestionsProvider =
    AsyncNotifierProvider.family<TextShoppingSuggestionsNotifier, List<ShoppingSuggestion>, String>(
  TextShoppingSuggestionsNotifier.new,
);
