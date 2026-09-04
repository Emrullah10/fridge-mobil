import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/features/billing/domain/entitlements.dart';

void main() {
  group('Entitlements.fromJson', () {
    test('backend gövdesini doğru ayrıştırır (trial, boosted olmayan kota)', () {
      final json = {
        'plan': 'trial',
        'source': 'reverse_trial',
        'status': 'active',
        'trialEndsAt': '2026-09-17T12:54:10.529Z',
        'periodEndsAt': null,
        'features': {'barcode': true, 'export': true, 'expiryNotify': true},
        'quotas': {
          'receipt': {'limit': 300, 'used': 0, 'boosted': false, 'resetsAt': '2026-09-30T21:00:00.000Z'},
        },
        'households': {
          'h1': {'ownerPlan': 'free', 'maxMembers': 2, 'maxLocations': 6, 'insightsWindowDays': 30},
        },
      };

      final result = Entitlements.fromJson(json);

      expect(result.plan, PlanTier.trial);
      expect(result.isTrial, isTrue);
      expect(result.isGuest, isFalse);
      expect(result.isPremium, isFalse);
      expect(result.quotaFor('receipt')!.limit, 300);
      expect(result.quotaFor('receipt')!.boosted, isFalse);
      expect(result.households['h1']!.maxLocations, 6);
      expect(result.trialEndsAt, isNotNull);
    });

    test('bilinmeyen plan string\'i sessizce free\'ye düşer — boot asla çökmez', () {
      final result = Entitlements.fromJson({'plan': 'something-new'});
      expect(result.plan, PlanTier.free);
    });

    test('quotas/households/features hiç yoksa boş map ile çöker değil', () {
      final result = Entitlements.fromJson({'plan': 'free'});
      expect(result.quotas, isEmpty);
      expect(result.households, isEmpty);
      expect(result.features, isEmpty);
      expect(result.quotaFor('receipt'), isNull);
    });
  });

  group('AiQuota', () {
    test('limit=null -> isUnlimited true, isExhausted her zaman false', () {
      const quota = AiQuota(limit: null, used: 99999, boosted: false);
      expect(quota.isUnlimited, isTrue);
      expect(quota.isExhausted, isFalse);
    });

    test('used >= limit -> isExhausted true', () {
      const quota = AiQuota(limit: 10, used: 10, boosted: false);
      expect(quota.isExhausted, isTrue);
    });

    test('used < limit -> isExhausted false, usageRatio doğru hesaplanır', () {
      const quota = AiQuota(limit: 10, used: 3, boosted: false);
      expect(quota.isExhausted, isFalse);
      expect(quota.usageRatio, closeTo(0.3, 0.001));
    });

    test('limit=0 -> usageRatio 0 döner, sıfıra bölme çökmez', () {
      const quota = AiQuota(limit: 0, used: 0, boosted: false);
      expect(quota.usageRatio, 0);
    });
  });

  group('Entitlements.trialDaysLeft', () {
    test('trialEndsAt null ise null döner', () {
      const entitlements = Entitlements.empty;
      expect(entitlements.trialDaysLeft, isNull);
    });

    test('deneme geçmişte bitmişse negatif değil sıfır döner', () {
      final json = {
        'plan': 'free',
        'trialEndsAt': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      };
      final result = Entitlements.fromJson(json);
      expect(result.trialDaysLeft, 0);
    });

    test('deneme gelecekte bitiyorsa kalan gün sayısını verir', () {
      final json = {
        'plan': 'trial',
        'trialEndsAt': DateTime.now().add(const Duration(days: 7, hours: 1)).toIso8601String(),
      };
      final result = Entitlements.fromJson(json);
      expect(result.trialDaysLeft, 7);
    });
  });

  group('Entitlements.empty', () {
    test('güvenli varsayılan — GUEST, hiçbir kota/özellik açık değil', () {
      const entitlements = Entitlements.empty;
      expect(entitlements.plan, PlanTier.guest);
      expect(entitlements.isGuest, isTrue);
      expect(entitlements.quotas, isEmpty);
    });
  });
}
