import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/features/onboarding/presentation/spotlight/coach_tour.dart';

/// SpotlightPainter'ın o an çizdiği hedef dikdörtgeni CustomPaint'ten okur.
Rect _spotlightTarget(WidgetTester tester) {
  final cp = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
        (w) => w.painter.runtimeType.toString() == 'SpotlightPainter',
      );
  // SpotlightPainter.target alanı — dynamic erişim (sınıf private değil ama
  // test tarafından import edilmiyor).
  return (cp.painter as dynamic).target as Rect;
}

void main() {
  testWidgets('hedef hareket ederse spotlight ona yapışır (tek seferlik ölçüm regresyonu)', (tester) async {
    final targetKey = GlobalKey();
    final topNotifier = ValueNotifier<double>(100);
    addTearDown(topNotifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: topNotifier,
            builder: (context, top, _) => Stack(
              children: [
                Positioned(
                  left: 40,
                  top: top,
                  child: Container(key: targetKey, width: 60, height: 40, color: Colors.green),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    unawaited(showCoachTour(
      context,
      steps: [
        CoachStep(targetKey: targetKey, title: 'Hedef', body: '', accent: Colors.blue),
      ],
      onFinished: () {},
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350)); // move animasyonu bitsin

    final before = _spotlightTarget(tester);
    expect(before.center.dy, closeTo(120, 6)); // top 100 + height/2

    // Hedefi kaydır — overlay pointer'ı yediği için programatik değişim.
    topNotifier.value = 400;
    await tester.pump(); // hedef yeni konuma layout olur
    await tester.pump(const Duration(milliseconds: 16)); // overlay'in bir nabız frame'i

    final after = _spotlightTarget(tester);
    expect(after.center.dy, greaterThan(before.center.dy + 100));
    expect(after.center.dy, closeTo(420, 8)); // top 400 + height/2
  });
}
