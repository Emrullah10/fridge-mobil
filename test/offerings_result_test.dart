import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/features/billing/data/purchase_repository.dart';

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
