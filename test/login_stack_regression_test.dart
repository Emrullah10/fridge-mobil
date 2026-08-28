import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fridge_mobil/core/api/api_client.dart';
import 'package:fridge_mobil/core/storage/device_id_storage.dart';
import 'package:fridge_mobil/features/auth/application/auth_providers.dart';
import 'package:fridge_mobil/features/auth/data/auth_repository.dart';
import 'package:fridge_mobil/features/auth/presentation/login_screen.dart';
import 'package:fridge_mobil/features/notification/application/notification_providers.dart';
import 'package:fridge_mobil/features/notification/data/push_service.dart';
import 'package:fridge_mobil/main.dart';

/// Gerçek PushService, FCM/flutter_local_notifications platform kanallarına
/// dokunur — widget testinde bunlar kurulu değil (LateInitializationError).
/// _AuthGate her oturum-açıklığı değişiminde bunu çağırır (main.dart:320),
/// testin amacı bu değil, bu yüzden no-op'a düşürüyoruz.
class _NoopPushService implements PushService {
  @override
  Future<void> registerForCurrentUser({PushNotificationTapHandler? onTap}) async {}

  @override
  Future<void> unregister() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Regresyon testi: main.dart:_AuthGate, oturum durumu değişince home'u
/// değiştirir ama push edilmiş route'lara dokunmazdı — bu yüzden login 200
/// dönüp state authenticated'a geçse bile LoginScreen ekranda asılı
/// kalıyordu (bkz. .wolf/buglog.json). _AuthGate artık isSignedIn !=
/// wasSignedIn olduğunda rootNavigatorKey ile köke kadar popUntil yapıyor;
/// bu test o davranışı sabitliyor.
class _FakeAuthController extends AuthController {
  _FakeAuthController(ApiClient client) : super(AuthRepository(client), DeviceIdStorage()) {
    // super constructor _restoreSession()'ı tetikler; test senaryosu için
    // hemen unauthenticated'a sabitliyoruz (gerçek bir HTTP çağrısı yok).
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  Future<void> login({required String email, required String password}) async {
    // Gerçek AuthRepository.login()'in yaptığı state geçişini taklit eder —
    // ağ çağrısı yok, doğrudan authenticated'a geçer.
    state = const AuthState(
      status: AuthStatus.authenticated,
      user: AppUser(id: 'u1', email: 'a@b.com', displayName: 'Test'),
    );
  }
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');
    SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true});
  });

  testWidgets('login sonrası LoginScreen yığında asılı kalmaz', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuthController(ref.watch(apiClientProvider))),
          pushServiceProvider.overrideWithValue(_NoopPushService()),
        ],
        child: const FridgeApp(),
      ),
    );

    // unauthenticated + onboarding görülmüş -> WelcomeScreen. Login'i doğrudan
    // kök navigator'a push ederek AuthCtaBlock akışını taklit ediyoruz.
    await tester.pump();
    rootNavigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    // login() tetiklenince controller senkron authenticated'a geçer.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoginScreen)),
    );
    await container.read(authControllerProvider.notifier).login(email: 'a@b.com', password: '123456');

    // _AuthGate rebuild + post-frame popUntil için birkaç pump gerekir.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
  });
}
