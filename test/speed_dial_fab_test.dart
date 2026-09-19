import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mobil/core/widgets/speed_dial_fab.dart';

// Speed-dial paketle (flutter_expandable_fab) yeniden yazıldıktan sonra
// sözleşmenin korunduğunu doğrular: kapalıyken etiketler görünmez, ana FAB'a
// basınca açılır, öğeye basınca hem aksiyon çalışır hem menü kapanır, ve
// coach tour'un kullandığı programatik open()/close() çalışır.
void main() {
  final fabKey = GlobalKey();
  final dialKey = GlobalKey<SpeedDialFabState>();

  Widget harness({required VoidCallback onAction}) => MaterialApp(
        home: Scaffold(
          floatingActionButtonLocation: SpeedDialFab.location,
          floatingActionButton: SpeedDialFab(
            key: dialKey,
            fabKey: fabKey,
            heroTag: 'test_dial',
            icon: Icons.add_rounded,
            actions: [
              SpeedDialAction(
                icon: Icons.auto_awesome_rounded,
                label: 'AI Asistan',
                heroTag: 'a',
                onPressed: onAction,
              ),
              SpeedDialAction(
                icon: Icons.document_scanner_rounded,
                label: 'Fiş Tara',
                heroTag: 'b',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

  testWidgets('kapalıyken etiket görünmez, ana FAB basınca açılır',
      (tester) async {
    await tester.pumpWidget(harness(onAction: () {}));
    await tester.pumpAndSettle();

    expect(dialKey.currentState!.isOpen, isFalse);

    await tester.tap(find.byKey(fabKey));
    await tester.pumpAndSettle();

    expect(dialKey.currentState!.isOpen, isTrue);
    expect(find.text('AI Asistan'), findsOneWidget);
    expect(find.text('Fiş Tara'), findsOneWidget);
  });

  testWidgets('öğeye basınca aksiyon çalışır ve menü kapanır', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(harness(onAction: () => tapped++));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(fabKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI Asistan'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(dialKey.currentState!.isOpen, isFalse);
  });

  testWidgets('coach tour için programatik open/close çalışır',
      (tester) async {
    await tester.pumpWidget(harness(onAction: () {}));
    await tester.pumpAndSettle();

    // suppressBarrier: overlay'i kapatmak için bir frame bekler.
    dialKey.currentState!.open(suppressBarrier: true);
    await tester.pumpAndSettle();
    expect(dialKey.currentState!.isOpen, isTrue);

    dialKey.currentState!.close();
    await tester.pumpAndSettle();
    expect(dialKey.currentState!.isOpen, isFalse);
  });
}
