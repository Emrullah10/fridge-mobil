import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:fridge_mobil/features/billing/data/purchase_repository.dart';
import 'package:fridge_mobil/features/billing/presentation/widgets/product_tile.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

PricingPhase _phase({required OfferPaymentMode mode, required double price, int? billingCycleCount}) => PricingPhase(
      const Period(PeriodUnit.month, 1, 'P1M'),
      RecurrenceMode.finiteRecurring,
      billingCycleCount,
      Price('₺${price.toStringAsFixed(2)}', (price * 1000000).round(), 'TRY'),
      mode,
    );

void main() {
  testWidgets('sade ürün — sadece fiyat, rozet/açıklama yok', (tester) async {
    const product = PurchaseProduct(identifier: 'p1', priceString: '₺79,99', title: 'Aylık', description: 'desc');
    await tester.pumpWidget(_wrap(ProductTile(product: product, selected: false, onTap: () {})));

    expect(find.text('₺79,99'), findsOneWidget);
    expect(find.textContaining('ÜCRETSİZ'), findsNothing);
    expect(find.textContaining('İNDİRİM'), findsNothing);
  });

  testWidgets('ücretsiz deneme — rozet ve açıklama satırı gösterilir', (tester) async {
    final product = PurchaseProduct(
      identifier: 'p1',
      priceString: '₺79,99',
      title: 'Yıllık',
      description: 'desc',
      freePhase: _phase(mode: OfferPaymentMode.freeTrial, price: 0, billingCycleCount: 1),
    );
    await tester.pumpWidget(_wrap(ProductTile(product: product, selected: false, onTap: () {})));

    expect(find.textContaining('ÜCRETSİZ'), findsOneWidget);
    expect(find.textContaining('İlk 1 ay ücretsiz, sonra ₺79,99'), findsOneWidget);
  });

  testWidgets('indirimli giriş fiyatı — eski fiyat üstü çizili, yeni fiyat vurgulu', (tester) async {
    final product = PurchaseProduct(
      identifier: 'p1',
      priceString: '₺79,99',
      title: 'Yıllık',
      description: 'desc',
      introPhase: _phase(mode: OfferPaymentMode.discountedRecurringPayment, price: 29.99, billingCycleCount: 3),
    );
    await tester.pumpWidget(_wrap(ProductTile(product: product, selected: false, onTap: () {})));

    expect(find.textContaining('İNDİRİM'), findsOneWidget);
    expect(find.text('₺79,99'), findsOneWidget); // üstü çizili eski fiyat
    expect(find.text('₺29.99'), findsOneWidget); // yeni fiyat
    expect(find.textContaining('İlk 3 dönem'), findsOneWidget);
  });

  testWidgets('yıllık paket, indirim yok — aylık karşılığı ve tasarruf rozeti', (tester) async {
    const monthly = PurchaseProduct(identifier: 'm', priceString: '₺79,99', title: 'Aylık', description: 'd', price: 79.99);
    const yearly = PurchaseProduct(
      identifier: 'y',
      priceString: '₺599,99',
      title: 'Yıllık',
      description: 'd',
      price: 599.99,
      pricePerMonthString: '₺49,99',
    );
    await tester.pumpWidget(
      _wrap(ProductTile(product: yearly, selected: false, onTap: () {}, monthlyForComparison: monthly)),
    );

    expect(find.textContaining('TASARRUF'), findsOneWidget);
    expect(find.textContaining('₺49,99/ay'), findsOneWidget);
  });
}
