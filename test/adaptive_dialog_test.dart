import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/core/theme/app_theme.dart';
import 'package:fridge_mobil/core/ui/app_dialog.dart';

/// Platform ayrışması `Theme.of(context).platform` üzerinden test edilir
/// (`debugDefaultTargetPlatformOverride` DEĞİL) — global state sızdırmaz ve
/// üretimdeki gerçek kod yolunu (`AppTheme` -> `ThemeData.platform`) test
/// eder.
Widget _harness(TargetPlatform platform, WidgetBuilder builder) {
  return MaterialApp(
    theme: AppTheme.light().copyWith(platform: platform),
    home: Scaffold(body: Builder(builder: builder)),
  );
}

void main() {
  group('AppDialog.confirm', () {
    testWidgets('iOS\'ta CupertinoAlertDialog üretir, Material değil', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(TargetPlatform.iOS, (context) {
          return ElevatedButton(
            onPressed: () => AppDialog.confirm(context, title: 'Başlık'),
            child: const Text('aç'),
          );
        }),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Android\'de Material AlertDialog üretir', (tester) async {
      await tester.pumpWidget(
        _harness(TargetPlatform.android, (context) {
          return ElevatedButton(
            onPressed: () => AppDialog.confirm(context, title: 'Başlık'),
            child: const Text('aç'),
          );
        }),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('$platform: iptal false, onay true döner', (tester) async {
        bool? result;
        await tester.pumpWidget(
          _harness(platform, (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await AppDialog.confirm(
                  context,
                  title: 'Silinsin mi?',
                  confirmLabel: 'Sil',
                  cancelLabel: 'Vazgeç',
                );
              },
              child: const Text('aç'),
            );
          }),
        );

        await tester.tap(find.text('aç'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vazgeç'));
        await tester.pumpAndSettle();
        expect(result, isFalse);

        await tester.tap(find.text('aç'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sil'));
        await tester.pumpAndSettle();
        expect(result, isTrue);
      });
    }

    testWidgets('Android\'de barrier\'a dokununca false döner (null değil)', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _harness(TargetPlatform.android, (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await AppDialog.confirm(context, title: 'Başlık');
            },
            child: const Text('aç'),
          );
        }),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      // Dialog dışına, barrier üstüne dokun.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets(
      'isDestructive: iOS\'ta CupertinoDialogAction.isDestructiveAction true',
      (tester) async {
        await tester.pumpWidget(
          _harness(TargetPlatform.iOS, (context) {
            return ElevatedButton(
              onPressed: () => AppDialog.confirm(
                context,
                title: 'Sil',
                confirmLabel: 'Sil',
                isDestructive: true,
              ),
              child: const Text('aç'),
            );
          }),
        );
        await tester.tap(find.text('aç'));
        await tester.pumpAndSettle();

        final actions = tester
            .widgetList<CupertinoDialogAction>(
              find.byType(CupertinoDialogAction),
            )
            .toList();
        final confirmAction = actions.firstWhere(
          (a) => (a.child as Text).data == 'Sil',
        );
        expect(confirmAction.isDestructiveAction, isTrue);
      },
    );

    testWidgets(
      'isDestructive: Android\'de onay butonu error rengiyle dolgulanır',
      (tester) async {
        await tester.pumpWidget(
          _harness(TargetPlatform.android, (context) {
            return ElevatedButton(
              onPressed: () => AppDialog.confirm(
                context,
                title: 'Sil',
                confirmLabel: 'Sil',
                isDestructive: true,
              ),
              child: const Text('aç'),
            );
          }),
        );
        await tester.tap(find.text('aç'));
        await tester.pumpAndSettle();

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Sil'),
        );
        final theme = AppTheme.light();
        final bg = button.style!.backgroundColor!.resolve({});
        expect(bg, theme.colorScheme.error);
      },
    );

    testWidgets('icon: iOS\'ta çizilmez', (tester) async {
      await tester.pumpWidget(
        _harness(TargetPlatform.iOS, (context) {
          return ElevatedButton(
            onPressed: () => AppDialog.confirm(
              context,
              title: 'Sil',
              icon: Icons.warning_amber_rounded,
            ),
            child: const Text('aç'),
          );
        }),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('icon: Android\'de çizilir', (tester) async {
      await tester.pumpWidget(
        _harness(TargetPlatform.android, (context) {
          return ElevatedButton(
            onPressed: () => AppDialog.confirm(
              context,
              title: 'Sil',
              icon: Icons.warning_amber_rounded,
            ),
            child: const Text('aç'),
          );
        }),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('AppDialog.prompt', () {
    testWidgets('boş metinle onaya basınca dialog kapanmaz, hata görünür', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _harness(TargetPlatform.android, (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await AppDialog.prompt(
                context,
                title: 'Ad',
                hintText: 'Adını gir',
              );
            },
            child: const Text('aç'),
          );
        }),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      // Dialog hâlâ açık: TextField hâlâ bulunabilir.
      expect(find.byType(TextField), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(find.byType(TextField), 'Emrullah');
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      expect(result, 'Emrullah');
    });

    testWidgets('aç-kapa döngüsünde controller dispose regresyonu yok', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(TargetPlatform.android, (context) {
          return ElevatedButton(
            onPressed: () =>
                AppDialog.prompt(context, title: 'Ad', hintText: 'Adını gir'),
            child: const Text('aç'),
          );
        }),
      );

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('aç'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'deneme $i');
        await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });

    // BUG (2026-09-12 düzeltildi): kullanıcı gerçek cihazda metin girişi
    // içeren alert'lerin ("Ne almalıyım?" AI önerisi, Ayarlar'daki ad/şifre
    // girişleri) UX olarak yanlış olduğunu bildirdi — AppDialog.prompt
    // artık bir alert DEĞİL, bir sheet (showAppPromptSheet) açıyor. Bu test
    // eskiden CupertinoAlertDialog + CupertinoTextField bekliyordu, o
    // davranış kasıtlı olarak kaldırıldı.
    testWidgets('bir alert DEĞİL, sheet açar (platformdan bağımsız)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(TargetPlatform.iOS, (context) {
          return ElevatedButton(
            onPressed: () =>
                AppDialog.prompt(context, title: 'Ad', hintText: 'Adını gir'),
            child: const Text('aç'),
          );
        }),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    });
  });
}
