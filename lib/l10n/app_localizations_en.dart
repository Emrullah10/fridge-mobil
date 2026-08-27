// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fridge';

  @override
  String get navAreas => 'My Spaces';

  @override
  String get navShopping => 'Shopping';

  @override
  String get navRecipes => 'Recipes';

  @override
  String get navInsights => 'Money';

  @override
  String get navSettings => 'Settings';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get insightsTitle => 'Money & Waste';

  @override
  String get insightsSaved => 'Saved';

  @override
  String get insightsWasted => 'Wasted';

  @override
  String get insightsSpent => 'Bought this period';

  @override
  String get insightsRangeThisMonth => 'This month';

  @override
  String get insightsRangeLastMonth => 'Last month';

  @override
  String get insightsRange90Days => 'Last 90 days';

  @override
  String get insightsByCategory => 'By category';

  @override
  String get insightsByMember => 'By person';

  @override
  String get insightsTopWasted => 'Most wasted';

  @override
  String get insightsEmptyTitle => 'No data for this period yet';

  @override
  String insightsMissingPrice(int count) {
    return '$count movements were excluded from totals because they have no price.';
  }

  @override
  String get chefTitle => 'AI Chef';

  @override
  String get chefHint => 'Ask something about your kitchen...';

  @override
  String get chefClearHistory => 'Clear chat';

  @override
  String get chefAddToList => 'Add to your list?';

  @override
  String get consumeQuestion => 'What happened to this item?';

  @override
  String get consumeUsed => 'Used it';

  @override
  String get consumeSpoiled => 'Spoiled';

  @override
  String get barcodeScan => 'Scan Barcode';

  @override
  String get barcodeAlign => 'Align the product barcode within the frame';

  @override
  String get barcodeNotFound =>
      'Barcode not recognized. You can pick the product manually.';

  @override
  String get voiceUnavailable => 'Voice input is not available on this device';

  @override
  String get dietTitle => 'Diet & Allergens';

  @override
  String get dietPreference => 'Dietary preference';

  @override
  String get dietAllergens => 'Allergens / avoided ingredients';

  @override
  String get dietKcalTarget => 'Daily calorie target (optional)';

  @override
  String get nutritionPerServing => 'Per serving';

  @override
  String get nutritionApprox => 'approx.';
}
