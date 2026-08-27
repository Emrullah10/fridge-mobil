// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppL10nTr extends AppL10n {
  AppL10nTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Fridge';

  @override
  String get navAreas => 'Alanlarım';

  @override
  String get navShopping => 'Alışveriş';

  @override
  String get navRecipes => 'Tarifler';

  @override
  String get navInsights => 'Para';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get commonCancel => 'İptal';

  @override
  String get commonSave => 'Kaydet';

  @override
  String get commonDelete => 'Sil';

  @override
  String get commonRetry => 'Yeniden dene';

  @override
  String get commonSomethingWentWrong => 'Bir şeyler ters gitti';

  @override
  String get insightsTitle => 'Para & İsraf';

  @override
  String get insightsSaved => 'Kurtarılan';

  @override
  String get insightsWasted => 'İsraf';

  @override
  String get insightsSpent => 'Bu dönem alışverişe giren';

  @override
  String get insightsRangeThisMonth => 'Bu ay';

  @override
  String get insightsRangeLastMonth => 'Geçen ay';

  @override
  String get insightsRange90Days => 'Son 90 gün';

  @override
  String get insightsByCategory => 'Kategoriye göre';

  @override
  String get insightsByMember => 'Kişiye göre';

  @override
  String get insightsTopWasted => 'En çok israf edilenler';

  @override
  String get insightsEmptyTitle => 'Bu dönem için henüz veri yok';

  @override
  String insightsMissingPrice(int count) {
    return '$count hareket fiyatsız olduğu için toplamlara katılmadı.';
  }

  @override
  String get chefTitle => 'AI Chef';

  @override
  String get chefHint => 'Mutfağınla ilgili bir şey sor...';

  @override
  String get chefClearHistory => 'Sohbeti temizle';

  @override
  String get chefAddToList => 'Listene eklemek ister misin?';

  @override
  String get consumeQuestion => 'Bu üründen ne oldu?';

  @override
  String get consumeUsed => 'Kullandım';

  @override
  String get consumeSpoiled => 'Bozuldu';

  @override
  String get barcodeScan => 'Barkod Okut';

  @override
  String get barcodeAlign => 'Ürünün barkodunu çerçeveye hizala';

  @override
  String get barcodeNotFound => 'Barkod tanınmadı. Ürünü elle seçebilirsin.';

  @override
  String get voiceUnavailable => 'Sesli giriş bu cihazda kullanılamıyor';

  @override
  String get dietTitle => 'Diyet & Alerjenler';

  @override
  String get dietPreference => 'Beslenme tercihi';

  @override
  String get dietAllergens => 'Alerjenler / kaçınılan malzemeler';

  @override
  String get dietKcalTarget => 'Günlük kalori hedefi (opsiyonel)';

  @override
  String get nutritionPerServing => 'Porsiyon başına';

  @override
  String get nutritionApprox => 'yaklaşık';
}
