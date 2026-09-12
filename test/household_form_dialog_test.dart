import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/core/ui/app_switch.dart';
import 'package:fridge_mobil/core/widgets/household_kind.dart';
import 'package:fridge_mobil/features/household/data/household_repository.dart';
import 'package:fridge_mobil/features/household/presentation/create_household_dialog.dart';
import 'package:fridge_mobil/features/household/presentation/edit_storage_location_dialog.dart';

Future<HouseholdFormResult?> _openDialog(
  WidgetTester tester, {
  Household? existing,
}) async {
  HouseholdFormResult? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showHouseholdFormDialog(
                context,
                existing: existing,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('isim boşken "Oluştur" hata gösterir, dialog kapanmaz', (
    tester,
  ) async {
    await _openDialog(tester);

    await tester.tap(find.text('Oluştur'));
    await tester.pumpAndSettle();

    expect(find.text('Bir isim girin'), findsOneWidget);
    expect(find.text('Yeni Alan'), findsOneWidget); // dialog hâlâ açık
  });

  testWidgets('isim + varsayılan simge ile sonuç döner (yemek kapalı)', (
    tester,
  ) async {
    HouseholdFormResult? captured;
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
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

  testWidgets('düzenleme modu: başlık "Alanı Düzenle", yemek switch\'i yok', (
    tester,
  ) async {
    final existing = Household(
      id: 'hh-1',
      name: 'Ofisim',
      kind: 'office',
      features: const {'icon': 'business_rounded'},
    );
    await _openDialog(tester, existing: existing);

    expect(find.text('Alanı Düzenle'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);
    expect(find.byType(AppSwitchTile), findsNothing);
    // controller mevcut ismi taşıyor:
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Ofisim',
    );
  });

  group('showStorageLocationFormDialog', () {
    // Regresyon testi — bkz. bug: eskiden onay butonu
    // `controller.text.trim().isEmpty ? null : confirm` ile disabled
    // ediliyordu ve controller'a listener yoktu, bu yüzden "Yeni Bölüm"de
    // isim yazmak butonu rebuild ETMİYORDU (buton kalıcı olarak disabled
    // kalıyordu, bir tür/ikon çipine dokunulmadıkça).
    testWidgets(
      'Yeni Bölüm: isim yazınca "Oluştur" butonu aktif olur (P0 regresyonu)',
      (tester) async {
        StorageLocationFormResult? captured;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    captured = await showStorageLocationFormDialog(context);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Hiçbir çipe dokunmadan, SADECE isim yazarak buton aktif olmalı.
        await tester.enterText(find.byType(TextField), 'Kiler');
        await tester.pump();

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Oluştur'),
        );
        expect(button.onPressed, isNotNull);

        await tester.ensureVisible(find.text('Oluştur'));
        await tester.tap(find.text('Oluştur'));
        await tester.pumpAndSettle();

        expect(captured, isNotNull);
        expect(captured!.name, 'Kiler');
      },
    );

    testWidgets('Yeni Bölüm: isim boşken Oluştur inline hata gösterir', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showStorageLocationFormDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Oluştur'));
      await tester.tap(find.text('Oluştur'));
      await tester.pumpAndSettle();

      expect(find.text('Bir isim girin'), findsOneWidget);
      expect(find.text('Yeni Bölüm'), findsOneWidget); // sheet hâlâ açık
    });
  });
}
