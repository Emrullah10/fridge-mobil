import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/core/widgets/household_kind.dart';
import 'package:fridge_mobil/features/household/data/household_repository.dart';
import 'package:fridge_mobil/features/household/presentation/create_household_dialog.dart';

Future<HouseholdFormResult?> _openDialog(WidgetTester tester, {Household? existing}) async {
  HouseholdFormResult? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showHouseholdFormDialog(context, existing: existing);
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('isim boşken "Oluştur" hata gösterir, dialog kapanmaz', (tester) async {
    await _openDialog(tester);

    await tester.tap(find.text('Oluştur'));
    await tester.pumpAndSettle();

    expect(find.text('Bir isim girin'), findsOneWidget);
    expect(find.text('Yeni Alan'), findsOneWidget); // dialog hâlâ açık
  });

  testWidgets('isim + varsayılan simge ile sonuç döner (yemek kapalı)', (tester) async {
    HouseholdFormResult? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              captured = await showHouseholdFormDialog(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sığınak');
    await tester.tap(find.text('Oluştur'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.name, 'Sığınak');
    expect(captured!.foodEnabled, false);
    expect(captured!.icon, householdIconKeyForIcon(householdIconChoices.first));
  });

  testWidgets('düzenleme modu: başlık "Alanı Düzenle", yemek switch\'i yok', (tester) async {
    final existing = Household(
      id: 'hh-1',
      name: 'Ofisim',
      kind: 'office',
      features: const {'icon': 'business_rounded'},
    );
    await _openDialog(tester, existing: existing);

    expect(find.text('Alanı Düzenle'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    // controller mevcut ismi taşıyor:
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Ofisim');
  });
}
