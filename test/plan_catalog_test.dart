import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/features/billing/domain/plan_catalog.dart';

void main() {
  group('PlanLimits.fromJson', () {
    test('backend gövdesini doğru ayrıştırır', () {
      final json = {
        'ai': {'receipt': 10, 'recipe': 15, 'chef': 20, 'shopping': 15},
        'household': {'count': 2},
        'location': {'perHousehold': 6},
        'member': {'perHousehold': 2},
        'insights': {'windowDays': 30},
        'features': {'barcode': true, 'export': false},
      };

      final result = PlanLimits.fromJson(json);

      expect(result.aiReceipt, 10);
      expect(result.aiRecipe, 15);
      expect(result.householdCount, 2);
      expect(result.locationPerHousehold, 6);
      expect(result.memberPerHousehold, 2);
      expect(result.insightsWindowDays, 30);
      expect(result.barcode, isTrue);
      expect(result.export, isFalse);
    });

    test('sınırsız alanlar (null) korunur — UI "Sınırsız" göstermeli, 0 değil', () {
      final json = {
        'ai': {'receipt': null, 'recipe': null, 'chef': null, 'shopping': null},
        'household': {'count': null},
        'location': {'perHousehold': null},
        'member': {'perHousehold': null},
        'insights': {'windowDays': null},
        'features': {'barcode': true, 'export': true},
      };

      final result = PlanLimits.fromJson(json);

      expect(result.aiReceipt, isNull);
      expect(result.householdCount, isNull);
      expect(result.insightsWindowDays, isNull);
    });

    test('eksik alt objeler çökmez, güvenli varsayılana düşer', () {
      final result = PlanLimits.fromJson(const {});
      expect(result.aiReceipt, isNull);
      expect(result.barcode, isFalse);
      expect(result.export, isFalse);
    });
  });

  group('PlanCatalog.fromJson', () {
    test('free/premium ikisi de ayrıştırılır, familySeats taşınır', () {
      final json = {
        'platform': 'android',
        'plans': {
          'free': {
            'ai': {'receipt': 10, 'recipe': 15, 'chef': 20, 'shopping': 15},
            'household': {'count': 2},
            'location': {'perHousehold': 6},
            'member': {'perHousehold': 2},
            'insights': {'windowDays': 30},
            'features': {'barcode': true, 'export': false},
          },
          'premium': {
            'ai': {'receipt': 300, 'recipe': 500, 'chef': 1000, 'shopping': 500},
            'household': {'count': 10},
            'location': {'perHousehold': null},
            'member': {'perHousehold': 10},
            'insights': {'windowDays': null},
            'features': {'barcode': true, 'export': true},
          },
        },
        'familySeats': 5,
      };

      final catalog = PlanCatalog.fromJson(json);

      expect(catalog.free.aiReceipt, 10);
      expect(catalog.premium.aiReceipt, 300);
      expect(catalog.premium.locationPerHousehold, isNull);
      expect(catalog.familySeats, 5);
    });

    test('familySeats yoksa null döner (aile paketi satılmıyor)', () {
      final catalog = PlanCatalog.fromJson(const {'plans': <String, dynamic>{}});
      expect(catalog.familySeats, isNull);
    });
  });
}
