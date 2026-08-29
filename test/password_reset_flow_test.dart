import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/core/api/api_client.dart';
import 'package:fridge_mobil/features/auth/application/auth_providers.dart';
import 'package:fridge_mobil/features/auth/data/auth_repository.dart';
import 'package:fridge_mobil/features/auth/presentation/forgot_password_screen.dart';
import 'package:fridge_mobil/features/auth/presentation/reset_password_screen.dart';

/// Ağa hiç dokunmayan sahte repo — login_stack_regression_test.dart'taki
/// _FakeAuthController deseniyle aynı: gerçek sınıfı extend edip sadece
/// ihtiyaç duyulan metotları override eder.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient(onUnauthorized: () async {}));

  final requestedEmails = <String>[];
  final resetCalls = <Map<String, String>>[];
  bool shouldThrowOnReset = false;

  @override
  Future<void> requestPasswordReset({required String email}) async {
    requestedEmails.add(email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (shouldThrowOnReset) {
      throw Exception('kod geçersiz');
    }
    resetCalls.add({'email': email, 'code': code, 'newPassword': newPassword});
  }
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');
  });

  testWidgets('kod gönder -> ResetPasswordScreen\'e geçer, yığında ForgotPasswordScreen kalmaz', (tester) async {
    final fakeRepo = _FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(home: ForgotPasswordScreen(initialEmail: 'a@test.local')),
      ),
    );

    await tester.tap(find.text('Kod Gönder'));
    await tester.pumpAndSettle();

    expect(fakeRepo.requestedEmails, ['a@test.local']);
    expect(find.byType(ForgotPasswordScreen), findsNothing);
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
  });

  testWidgets('doğru kod + yeni şifre ile reset başarılı olursa ResetPasswordScreen yığında kalmaz', (tester) async {
    final fakeRepo = _FakeAuthRepository();

    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          // ResetPasswordScreen'in popUntil(isFirst) çağrısını gerçekçi test
          // etmek için altında bir kök ekran (login taklidi) olması gerekir —
          // aksi halde screen kendisi zaten kök route olur ve pop no-op kalır.
          home: const Scaffold(body: Text('Login (kök)')),
        ),
      ),
    );

    navKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen(email: 'a@test.local')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.enterText(find.byType(TextFormField).last, 'yenisifre123');
    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pumpAndSettle();

    expect(fakeRepo.resetCalls, [
      {'email': 'a@test.local', 'code': '123456', 'newPassword': 'yenisifre123'},
    ]);
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(find.text('Login (kök)'), findsOneWidget);
  });

  testWidgets('hatalı kodda ekran açık kalır ve hata mesajı gösterilir', (tester) async {
    final fakeRepo = _FakeAuthRepository()..shouldThrowOnReset = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(home: ResetPasswordScreen(email: 'a@test.local')),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '000000');
    await tester.enterText(find.byType(TextFormField).last, 'yenisifre123');
    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
  });
}
