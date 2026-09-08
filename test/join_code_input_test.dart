import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/core/api/api_client.dart';
import 'package:fridge_mobil/core/widgets/form_error_text.dart';
import 'package:fridge_mobil/features/household/application/household_providers.dart';
import 'package:fridge_mobil/features/household/data/household_repository.dart';
import 'package:fridge_mobil/features/household/presentation/join_household_screen.dart';

/// Ağa hiç dokunmayan sahte repo — password_reset_flow_test.dart'taki
/// _FakeAuthRepository deseniyle aynı: gerçek sınıfı extend edip sadece
/// ihtiyaç duyulan metotları override eder.
class _FakeHouseholdRepository extends HouseholdRepository {
  _FakeHouseholdRepository() : super(ApiClient(onUnauthorized: () async {}));

  final acceptedCodes = <String>[];
  String? errorMessage;

  @override
  Future<void> acceptInvite(String code) async {
    if (errorMessage != null) {
      throw Exception(errorMessage);
    }
    acceptedCodes.add(code);
  }
}

Widget _wrap(_FakeHouseholdRepository repo, {String? initialCode}) {
  return ProviderScope(
    overrides: [householdRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      home: JoinHouseholdScreen(initialCode: initialCode),
    ),
  );
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');
  });

  Finder codeField() => find.byType(TextField);

  testWidgets('12 hane yazınca onCompleted (submit) tetiklenir', (
    tester,
  ) async {
    final repo = _FakeHouseholdRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(codeField(), 'a3f9c1d0e2b7');
    await tester.pumpAndSettle();

    expect(repo.acceptedCodes, ['a3f9c1d0e2b7']);
  });

  testWidgets("'a3f9 c1d0 e2b7' yapıştırınca boşluklar düşer, 12 hane olur", (
    tester,
  ) async {
    final repo = _FakeHouseholdRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(codeField(), 'a3f9 c1d0 e2b7');
    await tester.pumpAndSettle();

    expect(repo.acceptedCodes, ['a3f9c1d0e2b7']);
  });

  testWidgets('büyük harf küçüğe döner', (tester) async {
    final repo = _FakeHouseholdRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(codeField(), 'A3F9C1D0E2B7');
    await tester.pumpAndSettle();

    expect(repo.acceptedCodes, ['a3f9c1d0e2b7']);
  });

  testWidgets('hex-dışı karakter kabul edilmez', (tester) async {
    final repo = _FakeHouseholdRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(codeField(), 'xyz');
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(codeField());
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('13. karakter kabul edilmez, 12 hanede kırpılır', (
    tester,
  ) async {
    final repo = _FakeHouseholdRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(codeField(), 'a3f9c1d0e2b7ff');
    await tester.pumpAndSettle();

    // 12 haneye kırpılınca zaten tamamlanmış sayılır ve otomatik gönderilir.
    expect(repo.acceptedCodes, ['a3f9c1d0e2b7']);
  });

  testWidgets('12 haneden az iken "Katıl" butonu disabled', (tester) async {
    final repo = _FakeHouseholdRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(codeField(), 'a3f9c1d0');
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Katıl'),
    );
    expect(button.onPressed, isNull);
    expect(repo.acceptedCodes, isEmpty);
  });

  testWidgets(
    'acceptInvite hata atarsa ekran kapanmaz ve hata metni görünür',
    (tester) async {
      final repo = _FakeHouseholdRepository()..errorMessage = 'geçersiz kod';
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.enterText(codeField(), 'a3f9c1d0e2b7');
      await tester.pumpAndSettle();

      // Ekran hâlâ açık: kod alanı hâlâ bulunabilir olmalı, ayrıca hata
      // metni inline gösterilir (SnackBar değil).
      expect(codeField(), findsOneWidget);
      expect(find.byType(JoinHouseholdScreen), findsOneWidget);
      expect(find.byType(FormErrorText), findsOneWidget);
    },
  );

  testWidgets(
    'initialCode ile açılınca kutular dolu gelir ama otomatik gönderilmez',
    (tester) async {
      final repo = _FakeHouseholdRepository();
      await tester.pumpWidget(_wrap(repo, initialCode: 'a3f9c1d0e2b7'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(codeField());
      expect(field.controller!.text, 'a3f9c1d0e2b7');
      expect(repo.acceptedCodes, isEmpty);

      // Kullanıcı "Katıl"a basınca gönderilir.
      await tester.tap(find.widgetWithText(FilledButton, 'Katıl'));
      await tester.pumpAndSettle();
      expect(repo.acceptedCodes, ['a3f9c1d0e2b7']);
    },
  );
}
