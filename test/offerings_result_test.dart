import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:fridge_mobil/features/billing/data/purchase_repository.dart';

PricingPhase _phase({
  required OfferPaymentMode mode,
  required double price,
  int? billingCycleCount,
}) =>
    PricingPhase(
      const Period(PeriodUnit.month, 1, 'P1M'),
      RecurrenceMode.finiteRecurring,
      billingCycleCount,
      Price('₺${price.toStringAsFixed(2)}', (price * 1000000).round(), 'TRY'),
      mode,
    );

void main() {
  group('OfferingsResult', () {
    test('success taşır, failure null', () {
      const products = [
        PurchaseProduct(identifier: 'p1', priceString: '₺79,99', title: 'Aylık', description: 'desc'),
      ];
      const result = OfferingsResult.success(products);
      expect(result.products, products);
      expect(result.failure, isNull);
      expect(result.debugMessage, isNull);
    });

    test('failed products boş liste döner, failure/debugMessage taşınır', () {
      const result = OfferingsResult.failed(OfferingsFailure.storeError, debugMessage: 'network down');
      expect(result.products, isEmpty);
      expect(result.failure, OfferingsFailure.storeError);
      expect(result.debugMessage, 'network down');
    });

    test('failed debugMessage verilmezse null kalır', () {
      const result = OfferingsResult.failed(OfferingsFailure.noOffering);
      expect(result.debugMessage, isNull);
    });
  });

  group('PurchaseProduct — mağaza teklifi türetilmiş alanları', () {
    test('freePhase varsa hasFreeTrial true, hasIntroDiscount false', () {
      const product = PurchaseProduct(
        identifier: 'p1',
        priceString: '₺79,99',
        title: 'Yıllık',
        description: 'desc',
      );
      final withTrial = PurchaseProduct(
        identifier: product.identifier,
        priceString: product.priceString,
        title: product.title,
        description: product.description,
        freePhase: _phase(mode: OfferPaymentMode.freeTrial, price: 0, billingCycleCount: 1),
      );
      expect(withTrial.hasFreeTrial, isTrue);
      expect(withTrial.hasIntroDiscount, isFalse);
      expect(withTrial.trialPeriodLabel, '1 ay');
    });

    test('introPhase indirimli ödemeyse hasIntroDiscount true, hasFreeTrial false', () {
      final product = PurchaseProduct(
        identifier: 'p1',
        priceString: '₺79,99',
        title: 'Yıllık',
        description: 'desc',
        introPhase: _phase(mode: OfferPaymentMode.discountedRecurringPayment, price: 29.99, billingCycleCount: 3),
      );
      expect(product.hasIntroDiscount, isTrue);
      expect(product.hasFreeTrial, isFalse);
      expect(product.introPriceString, '₺29.99');
      expect(product.introCycles, 3);
    });

    test('hiçbir faz/introductoryPrice yoksa ikisi de false, tüm türetilmiş alanlar null', () {
      const product = PurchaseProduct(identifier: 'p1', priceString: '₺79,99', title: 'Aylık', description: 'desc');
      expect(product.hasFreeTrial, isFalse);
      expect(product.hasIntroDiscount, isFalse);
      expect(product.introPriceString, isNull);
      expect(product.introCycles, isNull);
      expect(product.trialPeriodLabel, isNull);
    });

    test('iOS introductoryPrice fallback — price 0 ise deneme, aksi hâlde indirim', () {
      const trial = PurchaseProduct(
        identifier: 'p1',
        priceString: '₺79,99',
        title: 'Aylık',
        description: 'desc',
        introductoryPrice: IntroductoryPrice(0, '₺0,00', 'P1W', 1, PeriodUnit.week, 1),
      );
      expect(trial.hasFreeTrial, isTrue);
      expect(trial.trialPeriodLabel, '1 hafta');

      const discount = PurchaseProduct(
        identifier: 'p2',
        priceString: '₺79,99',
        title: 'Aylık',
        description: 'desc',
        introductoryPrice: IntroductoryPrice(29.99, '₺29,99', 'P1M', 3, PeriodUnit.month, 1),
      );
      expect(discount.hasIntroDiscount, isTrue);
      expect(discount.hasFreeTrial, isFalse);
      expect(discount.introPriceString, '₺29,99');
      expect(discount.introCycles, 3);
    });

    test('discountPercentAgainst — yıllık/aylık kıyaslaması', () {
      const monthly = PurchaseProduct(identifier: 'm', priceString: '₺79,99', title: 'Aylık', description: 'd', price: 79.99);
      const yearly = PurchaseProduct(identifier: 'y', priceString: '₺599,99', title: 'Yıllık', description: 'd', price: 599.99);
      final percent = yearly.discountPercentAgainst(monthly);
      expect(percent, isNotNull);
      expect(percent, greaterThan(0));
    });

    test('discountPercentAgainst — price eksikse null döner', () {
      const yearly = PurchaseProduct(identifier: 'y', priceString: '₺599,99', title: 'Yıllık', description: 'd', price: 599.99);
      const monthlyNoPrice = PurchaseProduct(identifier: 'm', priceString: '₺79,99', title: 'Aylık', description: 'd');
      expect(yearly.discountPercentAgainst(monthlyNoPrice), isNull);
      expect(yearly.discountPercentAgainst(null), isNull);
    });
  });

  group('PurchaseRepository.fetchOfferings — configure() hiç çağrılmadıysa', () {
    test('notConfigured döner, RC plugin\'ına hiç dokunulmadan (boot çökmez ilkesi)', () async {
      // configure() bu testte hiç çağrılmadı — PurchaseRepository._configured
      // static olduğu için başka bir testte configure() çağrılmışsa bu test
      // yanıltıcı geçebilir; şu an projede configure()'ı çağıran bir test
      // yok, bu yüzden güvenli.
      final repository = PurchaseRepository();
      final result = await repository.fetchOfferings();
      expect(result.failure, OfferingsFailure.notConfigured);
      expect(result.products, isEmpty);
    });
  });
}
