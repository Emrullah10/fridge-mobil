import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Uygulama adı
  ///
  /// In tr, this message translates to:
  /// **'Fridge'**
  String get appTitle;

  /// No description provided for @navAreas.
  ///
  /// In tr, this message translates to:
  /// **'Alanlarım'**
  String get navAreas;

  /// No description provided for @navShopping.
  ///
  /// In tr, this message translates to:
  /// **'Alışveriş'**
  String get navShopping;

  /// No description provided for @navRecipes.
  ///
  /// In tr, this message translates to:
  /// **'Tarifler'**
  String get navRecipes;

  /// No description provided for @navInsights.
  ///
  /// In tr, this message translates to:
  /// **'Para'**
  String get navInsights;

  /// No description provided for @navSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get navSettings;

  /// No description provided for @commonCancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get commonRetry;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti'**
  String get commonSomethingWentWrong;

  /// No description provided for @insightsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Para & İsraf'**
  String get insightsTitle;

  /// No description provided for @insightsSaved.
  ///
  /// In tr, this message translates to:
  /// **'Kurtarılan'**
  String get insightsSaved;

  /// No description provided for @insightsWasted.
  ///
  /// In tr, this message translates to:
  /// **'İsraf'**
  String get insightsWasted;

  /// No description provided for @insightsSpent.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönem alışverişe giren'**
  String get insightsSpent;

  /// No description provided for @insightsRangeThisMonth.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay'**
  String get insightsRangeThisMonth;

  /// No description provided for @insightsRangeLastMonth.
  ///
  /// In tr, this message translates to:
  /// **'Geçen ay'**
  String get insightsRangeLastMonth;

  /// No description provided for @insightsRange90Days.
  ///
  /// In tr, this message translates to:
  /// **'Son 90 gün'**
  String get insightsRange90Days;

  /// No description provided for @insightsByCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriye göre'**
  String get insightsByCategory;

  /// No description provided for @insightsByMember.
  ///
  /// In tr, this message translates to:
  /// **'Kişiye göre'**
  String get insightsByMember;

  /// No description provided for @insightsTopWasted.
  ///
  /// In tr, this message translates to:
  /// **'En çok israf edilenler'**
  String get insightsTopWasted;

  /// No description provided for @insightsEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönem için henüz veri yok'**
  String get insightsEmptyTitle;

  /// No description provided for @insightsMissingPrice.
  ///
  /// In tr, this message translates to:
  /// **'{count} hareket fiyatsız olduğu için toplamlara katılmadı.'**
  String insightsMissingPrice(int count);

  /// No description provided for @chefTitle.
  ///
  /// In tr, this message translates to:
  /// **'AI Chef'**
  String get chefTitle;

  /// No description provided for @chefHint.
  ///
  /// In tr, this message translates to:
  /// **'Mutfağınla ilgili bir şey sor...'**
  String get chefHint;

  /// No description provided for @chefClearHistory.
  ///
  /// In tr, this message translates to:
  /// **'Sohbeti temizle'**
  String get chefClearHistory;

  /// No description provided for @chefAddToList.
  ///
  /// In tr, this message translates to:
  /// **'Listene eklemek ister misin?'**
  String get chefAddToList;

  /// No description provided for @consumeQuestion.
  ///
  /// In tr, this message translates to:
  /// **'Bu üründen ne oldu?'**
  String get consumeQuestion;

  /// No description provided for @consumeUsed.
  ///
  /// In tr, this message translates to:
  /// **'Kullandım'**
  String get consumeUsed;

  /// No description provided for @consumeSpoiled.
  ///
  /// In tr, this message translates to:
  /// **'Bozuldu'**
  String get consumeSpoiled;

  /// No description provided for @barcodeScan.
  ///
  /// In tr, this message translates to:
  /// **'Barkod Okut'**
  String get barcodeScan;

  /// No description provided for @barcodeAlign.
  ///
  /// In tr, this message translates to:
  /// **'Ürünün barkodunu çerçeveye hizala'**
  String get barcodeAlign;

  /// No description provided for @barcodeNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Barkod tanınmadı. Ürünü elle seçebilirsin.'**
  String get barcodeNotFound;

  /// No description provided for @voiceUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Sesli giriş bu cihazda kullanılamıyor'**
  String get voiceUnavailable;

  /// No description provided for @dietTitle.
  ///
  /// In tr, this message translates to:
  /// **'Diyet & Alerjenler'**
  String get dietTitle;

  /// No description provided for @dietPreference.
  ///
  /// In tr, this message translates to:
  /// **'Beslenme tercihi'**
  String get dietPreference;

  /// No description provided for @dietAllergens.
  ///
  /// In tr, this message translates to:
  /// **'Alerjenler / kaçınılan malzemeler'**
  String get dietAllergens;

  /// No description provided for @dietKcalTarget.
  ///
  /// In tr, this message translates to:
  /// **'Günlük kalori hedefi (opsiyonel)'**
  String get dietKcalTarget;

  /// No description provided for @nutritionPerServing.
  ///
  /// In tr, this message translates to:
  /// **'Porsiyon başına'**
  String get nutritionPerServing;

  /// No description provided for @nutritionApprox.
  ///
  /// In tr, this message translates to:
  /// **'yaklaşık'**
  String get nutritionApprox;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'tr':
      return AppL10nTr();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
