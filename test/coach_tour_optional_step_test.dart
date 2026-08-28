import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/features/onboarding/presentation/spotlight/coach_tour.dart';

void main() {
  testWidgets('hedefi ağaçta olmayan optional adım tura girmez', (tester) async {
    final presentKey = GlobalKey();
    final missingKey = GlobalKey(); // hiçbir widget'a takılı değil

    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(key: presentKey, width: 40, height: 40)),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    // await ETME: showCoachTour bir route push eder, döndürdüğü Future ancak
    // route pop olunca tamamlanır — await test gövdesini kilitler.
    unawaited(showCoachTour(
      context,
      steps: [
        CoachStep(targetKey: presentKey, title: 'Var', body: '', accent: Colors.blue),
        CoachStep(targetKey: missingKey, optional: true, title: 'Yok', body: '', accent: Colors.red),
      ],
      onFinished: () => finished = true,
    ));
    // Tur overlay'i sonsuz nabız animasyonu içerdiği için pumpAndSettle
    // kullanılamaz — birkaç frame pump yeterli.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Yalnız 1 adım gösterilmeli — balonun sayacı "1 / 1".
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Var'), findsOneWidget);
    expect(find.text('Yok'), findsNothing);

    // Tek adımlı turda "Bitti" ile kapanır.
    await tester.tap(find.text('Bitti'));
    // Tur overlay'i sonsuz nabız animasyonu içerdiği için pumpAndSettle
    // kullanılamaz — birkaç frame pump yeterli.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(finished, isTrue);
  });

  testWidgets('tüm adımlar hedefsiz optional ise tur hiç açılmaz, onFinished çağrılır', (tester) async {
    final missingA = GlobalKey();
    final missingB = GlobalKey();
    var finished = false;

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    final context = tester.element(find.byType(Scaffold));

    await showCoachTour(
      context,
      steps: [
        CoachStep(targetKey: missingA, optional: true, title: 'A', body: '', accent: Colors.blue),
        CoachStep(targetKey: missingB, optional: true, title: 'B', body: '', accent: Colors.red),
      ],
      onFinished: () => finished = true,
    );
    // Tur overlay'i sonsuz nabız animasyonu içerdiği için pumpAndSettle
    // kullanılamaz — birkaç frame pump yeterli.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(finished, isTrue);
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
  });
}
