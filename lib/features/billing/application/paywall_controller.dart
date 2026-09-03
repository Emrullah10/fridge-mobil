import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/api_error.dart';
import '../presentation/paywall_sheet.dart';

/// Paywall'ın NE ZAMAN gösterileceğini yöneten frekans kuralları (plan
/// §Faz 4 "Frekans kuralları"):
/// - Modal oturumda en fazla 1 (kota-doldu tetikleyicisi hariç — o her
///   zaman gösterilir, kullanıcının doğrudan aksiyonunun karşılığı).
/// - Aynı tetikleyici 7 günde 1 kez.
/// - "Şimdi değil" derse o tetikleyici 14 gün susar.
/// - İlk oturumda hiç gösterilmez (kota-doldu hariç).
enum PaywallTrigger {
  quotaExceeded,      // her zaman gösterilir, frekans kısıtı yok
  trialEndingSoon,    // 7 günde 1
  trialEnded,         // 1 kez (tam ekran, ayrı akış — bu controller'ın kapsamı dışı)
  usageWarning80,     // 24 saatte 1, banner (modal değil — burada tetiklenmez)
  lockedFeatureTap,   // her zaman (kullanıcının doğrudan aksiyonu)
  winBack,            // abonelik bitiminden 7 gün sonra, 1 kez
}

class PaywallController {
  PaywallController(this._prefs);

  final SharedPreferences _prefs;
  bool _shownThisSession = false;

  static const _dismissedPrefix = 'paywall_dismissed_until_';
  static const _lastShownPrefix = 'paywall_last_shown_';

  /// Test edilebilirlik için dışa açık — showPaywallSheet'in gerçek bir
  /// BuildContext/widget ağacı kurmadan frekans mantığını doğrudan test
  /// etmeyi sağlar (bkz. paywall_controller_test.dart).
  @visibleForTesting
  bool isFrequencyLimited(PaywallTrigger trigger) => _isFrequencyLimited(trigger);

  bool _isFrequencyLimited(PaywallTrigger trigger) {
    if (trigger == PaywallTrigger.quotaExceeded || trigger == PaywallTrigger.lockedFeatureTap) {
      return false; // kullanıcının doğrudan aksiyonu — her zaman gösterilir
    }
    if (_shownThisSession) return true;

    final dismissedUntil = _prefs.getInt('$_dismissedPrefix${trigger.name}');
    if (dismissedUntil != null && DateTime.now().millisecondsSinceEpoch < dismissedUntil) {
      return true;
    }

    final lastShown = _prefs.getInt('$_lastShownPrefix${trigger.name}');
    if (lastShown != null) {
      final daysSince = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastShown)).inDays;
      if (daysSince < 7) return true;
    }

    return false;
  }

  /// Test edilebilirlik için dışa açık.
  @visibleForTesting
  void recordShown(PaywallTrigger trigger) => _recordShown(trigger);

  void _recordShown(PaywallTrigger trigger) {
    _shownThisSession = true;
    _prefs.setInt('$_lastShownPrefix${trigger.name}', DateTime.now().millisecondsSinceEpoch);
  }

  void _recordDismissed(PaywallTrigger trigger) {
    final until = DateTime.now().add(const Duration(days: 14)).millisecondsSinceEpoch;
    _prefs.setInt('$_dismissedPrefix${trigger.name}', until);
  }

  /// Alt sayfayı gösterir — frekans kuralı izin vermiyorsa sessizce hiçbir
  /// şey yapmaz (çağıran taraf 402 hatasını yine de describeApiError ile
  /// bir SnackBar/inline hata olarak gösterebilir, paywall bunun yerine
  /// geçmez).
  Future<void> maybeShow(
    BuildContext context, {
    required PaywallTrigger trigger,
    PlanLimitInfo? info,
    VoidCallback? onUpgrade,
  }) async {
    if (_isFrequencyLimited(trigger)) return;
    _recordShown(trigger);
    await showPaywallSheet(context, info: info, onUpgrade: onUpgrade);
    // showPaywallSheet kapanınca (kullanıcı "Şimdi değil" veya dışarı
    // dokunarak kapattıysa) 14 günlük susturma başlar. "Yükselt"e bastıysa
    // zaten pop olup onUpgrade tetiklendiği için bu kayıt zararsız (kullanıcı
    // muhtemelen satın alma ekranına gitmiştir, aynı tetikleyiciyi tekrar
    // görmeyecek olması sorun değil).
    _recordDismissed(trigger);
  }
}

final _sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

final paywallControllerProvider = Provider<AsyncValue<PaywallController>>((ref) {
  final prefsAsync = ref.watch(_sharedPreferencesProvider);
  return prefsAsync.whenData((prefs) => PaywallController(prefs));
});
