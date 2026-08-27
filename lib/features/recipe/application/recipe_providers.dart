import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/recipe_repository.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(apiClientProvider));
});

final recipeSuggestionsProvider = FutureProvider.family<List<Recipe>, String>((ref, householdId) async {
  return ref.watch(recipeRepositoryProvider).listSuggestions(householdId);
});

final recipeListProvider = FutureProvider.family<List<Recipe>, String>((ref, householdId) async {
  return ref.watch(recipeRepositoryProvider).listAll(householdId);
});

final favoriteRecipeIdsProvider = FutureProvider.family<List<String>, String>((ref, householdId) async {
  return ref.watch(recipeRepositoryProvider).listFavoriteIds(householdId);
});

class RecipeDetailParams {
  const RecipeDetailParams({required this.householdId, required this.recipeId});
  final String householdId;
  final String recipeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeDetailParams && other.householdId == householdId && other.recipeId == recipeId);

  @override
  int get hashCode => Object.hash(householdId, recipeId);
}

final recipeDetailProvider = FutureProvider.family<Recipe, RecipeDetailParams>((ref, params) async {
  return ref.watch(recipeRepositoryProvider).getDetail(params.householdId, params.recipeId);
});
