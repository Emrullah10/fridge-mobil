import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/error/api_error.dart';
import '../../../core/storage/device_id_storage.dart';
import '../data/auth_repository.dart';

/// `guest`, `authenticated`in bir alt durumu DEĞİL, ayrı bir dal —
/// _AuthGate (main.dart) bu enum üzerinde switch yapıyor; buraya yeni bir
/// değer eklemek main.dart:313 ve main.dart:298'de DERLEME HATASI üretir.
/// Bu istenen davranış: hiçbir dal unutulmadan güncellenmiş olur.
enum AuthStatus { unknown, authenticated, guest, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.user});

  final AuthStatus status;
  final AppUser? user;

  static const initial = AuthState(status: AuthStatus.unknown);

  bool get isGuest => status == AuthStatus.guest;

  AuthState copyWith({AuthStatus? status, AppUser? user}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, this._deviceIdStorage) : super(AuthState.initial) {
    _restoreSession();
  }

  final AuthRepository _repo;
  final DeviceIdStorage _deviceIdStorage;

  AuthStatus _statusFor(AppUser user) => user.isGuest ? AuthStatus.guest : AuthStatus.authenticated;

  Future<void> _restoreSession() async {
    final hasSession = await _repo.hasStoredSession();
    if (!hasSession) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    // Token varlığı tek başına kullanıcı bilgisini (ad/e-posta/isGuest)
    // vermiyor — önceden burada user hep null kalıyordu, profil ekranı boş
    // görünürdü.
    try {
      final user = await _repo.fetchCurrentUser();
      state = AuthState(status: _statusFor(user), user: user);
    } catch (_) {
      // Token geçersizse ApiClient zaten 401 -> forceUnauthenticated akışını
      // tetikler; burada en azından authenticated'a düşüp uygulamanın
      // açılmasını engellememek yeterli. isGuest bilinmiyor — normal
      // authenticated varsayılır, 401 zaten unauthenticated'a düşürecek.
      state = const AuthState(status: AuthStatus.authenticated);
    }
  }

  Future<void> login({required String email, required String password}) async {
    final user = await _repo.login(email: email, password: password);
    state = AuthState(status: _statusFor(user), user: user);
  }

  Future<void> register({required String email, required String password, required String displayName}) async {
    // deviceId (varsa) 14 günlük ters denemenin cihaz-bazlı suistimal
    // korumasını besler — deviceIdStorage zaten misafir modu için var,
    // register'da yeniden kullanılır (kayıt duvarı olmadan denenmiş bir
    // misafir cihazı, hesap değiştirse bile ikinci deneme almasın).
    final deviceId = await _deviceIdStorage.getOrCreate();
    await _repo.register(email: email, password: password, displayName: displayName, deviceId: deviceId);
    await login(email: email, password: password);
  }

  /// Kayıt duvarı olmadan uygulamayı kullanmaya başlar — aynı cihazda
  /// tekrar çağrılırsa (uygulama kapatılıp açıldı) AYNI misafir hesabına
  /// döner, veri kaybetmez.
  Future<void> continueAsGuest() async {
    final deviceId = await _deviceIdStorage.getOrCreate();
    final user = await _repo.createGuest(deviceId);
    state = AuthState(status: AuthStatus.guest, user: user);
  }

  /// Misafir hesabını kalıcı hesaba yükseltir — oturum ve tüm veriler
  /// (alan/envanter/fiş) korunur, sadece durum authenticated'a geçer.
  Future<void> upgradeAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final deviceId = await _deviceIdStorage.getOrCreate();
    final user = await _repo.upgradeAccount(
      email: email,
      password: password,
      displayName: displayName,
      deviceId: deviceId,
    );
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> updateProfile({required String displayName, Object? dietProfile = _keepDiet}) async {
    final user = identical(dietProfile, _keepDiet)
        ? await _repo.updateProfile(displayName: displayName)
        : await _repo.updateProfile(displayName: displayName, dietProfile: dietProfile);
    state = state.copyWith(user: user);
  }

  static const _keepDiet = Object();

  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return _repo.changePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  Future<void> deleteAccount({required String password}) async {
    await _repo.deleteAccount(password: password);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void forceUnauthenticated() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// apiClientProvider ile authControllerProvider birbirine bağımlı olmamalı
// (401 -> forceUnauthenticated -> ApiClient yeniden kurulmaz). Bu yüzden
// ApiClient tek seferlik, değişmez bir callback alır; forceUnauthenticated
// çağrısı doğrudan bu callback üzerinden, provider grafiğine girmeden yapılır.
final _unauthorizedNotifier = ValueNotifier<int>(0);

/// 402 (plan/kota yetersizliği) — aynı çapraz-katman haberleşme deseni.
/// entitlements_providers.dart bunu dinleyip cache'i invalidate eder,
/// paywall_controller.dart bunu dinleyip tetikleyici gösterir. ApiClient
/// billing katmanını hiç import etmez.
final planLimitNotifier = ValueNotifier<PlanLimitInfo?>(null);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    onUnauthorized: () async {
      _unauthorizedNotifier.value++;
    },
    onPlanLimitReached: (info) {
      planLimitNotifier.value = info;
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final deviceIdStorageProvider = Provider<DeviceIdStorage>((ref) => DeviceIdStorage());

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(ref.watch(authRepositoryProvider), ref.watch(deviceIdStorageProvider));
  void listener() => controller.forceUnauthenticated();
  _unauthorizedNotifier.addListener(listener);
  ref.onDispose(() => _unauthorizedNotifier.removeListener(listener));
  return controller;
});
