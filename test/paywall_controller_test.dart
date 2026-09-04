import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fridge_mobil/features/billing/application/paywall_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> freshPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  group('PaywallController — frekans kuralları (plan §Faz 4)', () {
    test('quotaExceeded HİÇBİR ZAMAN frekans kısıtına takılmaz — kullanıcının doğrudan aksiyonu', () async {
      final prefs = await freshPrefs();
      final controller = PaywallController(prefs);
      controller.recordShown(PaywallTrigger.quotaExceeded);
      controller.recordShown(PaywallTrigger.quotaExceeded);

      expect(controller.isFrequencyLimited(PaywallTrigger.quotaExceeded), isFalse);
    });

    test('lockedFeatureTap da her zaman gösterilir — kullanıcının doğrudan aksiyonu', () async {
      final prefs = await freshPrefs();
      await prefs.setInt('paywall_last_shown_lockedFeatureTap', DateTime.now().millisecondsSinceEpoch);
      final controller = PaywallController(prefs);

      expect(controller.isFrequencyLimited(PaywallTrigger.lockedFeatureTap), isFalse);
    });

    test('modal oturumda en fazla 1: bir kez gösterildikten sonra AYNI oturumda tekrar limitlenir', () async {
      final prefs = await freshPrefs();
      final controller = PaywallController(prefs);

      expect(controller.isFrequencyLimited(PaywallTrigger.trialEndingSoon), isFalse);
      controller.recordShown(PaywallTrigger.trialEndingSoon);

      // Aynı oturumda BAŞKA bir tetikleyici bile artık limitli (modal-oturum kısıtı).
      expect(controller.isFrequencyLimited(PaywallTrigger.winBack), isTrue);
    });

    test('7 günden az önce gösterilmiş tetikleyici (yeni controller/oturumda bile) limitli kalır', () async {
      final prefs = await freshPrefs();
      await prefs.setInt(
        'paywall_last_shown_trialEndingSoon',
        DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch,
      );
      final controller = PaywallController(prefs); // yeni instance, session flag'i sıfır

      expect(controller.isFrequencyLimited(PaywallTrigger.trialEndingSoon), isTrue);
    });

    test('7 günden eski kayıt -> tekrar gösterilebilir', () async {
      final prefs = await freshPrefs();
      await prefs.setInt(
        'paywall_last_shown_trialEndingSoon',
        DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch,
      );
      final controller = PaywallController(prefs);

      expect(controller.isFrequencyLimited(PaywallTrigger.trialEndingSoon), isFalse);
    });

    test('"Şimdi değil" sonrası 14 gün susturma — dismissed_until gelecekteyse limitli', () async {
      final prefs = await freshPrefs();
      await prefs.setInt(
        'paywall_dismissed_until_winBack',
        DateTime.now().add(const Duration(days: 10)).millisecondsSinceEpoch,
      );
      final controller = PaywallController(prefs);

      expect(controller.isFrequencyLimited(PaywallTrigger.winBack), isTrue);
    });

    test('14 günlük susturma süresi geçmişse tekrar gösterilebilir', () async {
      final prefs = await freshPrefs();
      await prefs.setInt(
        'paywall_dismissed_until_winBack',
        DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      );
      final controller = PaywallController(prefs);

      expect(controller.isFrequencyLimited(PaywallTrigger.winBack), isFalse);
    });

    test('hiç kayıt yoksa (ilk kez) frekans kısıtlamaz', () async {
      final prefs = await freshPrefs();
      final controller = PaywallController(prefs);

      expect(controller.isFrequencyLimited(PaywallTrigger.usageWarning80), isFalse);
    });
  });
}
