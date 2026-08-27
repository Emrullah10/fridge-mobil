import '../../../core/api/api_client.dart';

class RecipeStep {
  const RecipeStep({required this.order, required this.text, this.minutes});
  final int order;
  final String text;
  final int? minutes;

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        order: json['order'] as int,
        text: json['text'] as String,
        minutes: json['minutes'] as int?,
      );
}

// 'available' | 'partial' | 'missing' | 'unit_mismatch'
//
// productId artık null olabilir: tarif AI'ı envanterde eşleşmeyen bir
// malzeme için yeni bir ürün yaratmıyor (katalog kirlenmesin diye), bunun
// yerine serbest metin (backend'de custom_name) olarak saklıyor. Bu tür
// malzemeler envanterde asla eşleşemez, matchStatus her zaman 'missing' gelir.
class RecipeIngredient {
  const RecipeIngredient({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.isOptional,
    this.matchStatus,
  });

  final String? productId;
  final String productName;
  final double quantity;
  final String unit;
  final bool isOptional;
  final String? matchStatus;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
        productId: json['productId'] as String?,
        productName: json['productName'] as String? ?? 'Bilinmeyen ürün',
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String,
        isOptional: json['isOptional'] as bool? ?? false,
        matchStatus: json['matchStatus'] as String?,
      );
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
    required this.instructions,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.generatedBy,
    this.totalIngredients,
    this.availableIngredients,
    this.missingCount,
    this.ingredients = const [],
    this.nutrition,
  });

  final String id;
  final String title;
  final String? description;
  final List<RecipeStep> steps;
  final String instructions;
  final int? servings;
  final int? prepMinutes;
  final int? cookMinutes;
  final String? difficulty;
  final String generatedBy;
  final int? totalIngredients;
  final int? availableIngredients;
  final int? missingCount;
  final List<RecipeIngredient> ingredients;

  /// Sadece tarif detayında dolu (get-recipe-detail). Okuma anında hesaplanır.
  final RecipeNutrition? nutrition;

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        steps: (json['steps'] as List?)?.map((s) => RecipeStep.fromJson(s as Map<String, dynamic>)).toList() ?? [],
        instructions: json['instructions'] as String? ?? '',
        servings: json['servings'] as int?,
        prepMinutes: json['prepMinutes'] as int?,
        cookMinutes: json['cookMinutes'] as int?,
        difficulty: json['difficulty'] as String?,
        generatedBy: json['generatedBy'] as String? ?? 'user',
        totalIngredients: json['totalIngredients'] as int?,
        availableIngredients: json['availableIngredients'] as int?,
        missingCount: json['missingCount'] as int?,
        ingredients: (json['ingredients'] as List?)
                ?.map((i) => RecipeIngredient.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [],
        nutrition: json['nutrition'] != null
            ? RecipeNutrition.fromJson(json['nutrition'] as Map<String, dynamic>)
            : null,
      );
}

class RecipeNutrition {
  const RecipeNutrition({
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
    required this.complete,
    required this.skippedIngredients,
  });

  final int kcal;
  final double protein;
  final double carb;
  final double fat;

  /// false ise bazı malzemelerin besin verisi yoktu — değer "yaklaşık".
  final bool complete;
  final int skippedIngredients;

  factory RecipeNutrition.fromJson(Map<String, dynamic> json) {
    final per = json['perServing'] as Map<String, dynamic>? ?? const {};
    return RecipeNutrition(
      kcal: (per['kcal'] as num?)?.round() ?? 0,
      protein: (per['protein'] as num?)?.toDouble() ?? 0,
      carb: (per['carb'] as num?)?.toDouble() ?? 0,
      fat: (per['fat'] as num?)?.toDouble() ?? 0,
      complete: json['complete'] as bool? ?? false,
      skippedIngredients: (json['skippedIngredients'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasData => kcal > 0 || protein > 0 || carb > 0 || fat > 0;
}

class CookResult {
  const CookResult({required this.insufficientCount});
  final int insufficientCount;

  factory CookResult.fromJson(Map<String, dynamic> json) => CookResult(
        insufficientCount: (json['insufficient'] as List?)?.length ?? 0,
      );
}

class RecipeRepository {
  RecipeRepository(this._client);

  final ApiClient _client;

  String _base(String householdId) => '/households/$householdId/recipes';

  Future<List<Recipe>> listSuggestions(String householdId) async {
    final response = await _client.dio.get('${_base(householdId)}/suggestions');
    return (response.data['suggestions'] as List).map((r) => Recipe.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<Recipe>> listAll(String householdId) async {
    final response = await _client.dio.get(_base(householdId));
    return (response.data['recipes'] as List).map((r) => Recipe.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<String>> listFavoriteIds(String householdId) async {
    final response = await _client.dio.get('${_base(householdId)}/favorites');
    return (response.data['recipeIds'] as List).cast<String>();
  }

  Future<Recipe> getDetail(String householdId, String recipeId) async {
    final response = await _client.dio.get('${_base(householdId)}/$recipeId');
    return Recipe.fromJson(response.data['recipe'] as Map<String, dynamic>);
  }

  Future<List<Recipe>> generateAiRecipes(String householdId, {Map<String, dynamic>? preferences}) async {
    final response = await _client.dio.post(
      '${_base(householdId)}/generate',
      data: {'preferences': preferences ?? {}},
    );
    return (response.data['recipes'] as List).map((r) => Recipe.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<CookResult> cook(String householdId, String recipeId) async {
    final response = await _client.dio.post('${_base(householdId)}/$recipeId/cook');
    return CookResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setFavorite(String householdId, String recipeId, bool favorite) async {
    if (favorite) {
      await _client.dio.post('${_base(householdId)}/$recipeId/favorite');
    } else {
      await _client.dio.delete('${_base(householdId)}/$recipeId/favorite');
    }
  }

  Future<void> delete(String householdId, String recipeId) async {
    await _client.dio.delete('${_base(householdId)}/$recipeId');
  }
}
