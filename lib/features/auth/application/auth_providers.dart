import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.user});

  final AuthStatus status;
  final AppUser? user;

  static const initial = AuthState(status: AuthStatus.unknown);

  AuthState copyWith({AuthStatus? status, AppUser? user}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(AuthState.initial) {
    _restoreSession();
  }

  final AuthRepository _repo;

  Future<void> _restoreSession() async {
    final hasSession = await _repo.hasStoredSession();
    state = AuthState(status: hasSession ? AuthStatus.authenticated : AuthStatus.unauthenticated);
  }

  Future<void> login({required String email, required String password}) async {
    final user = await _repo.login(email: email, password: password);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> register({required String email, required String password, required String displayName}) async {
    await _repo.register(email: email, password: password, displayName: displayName);
    await login(email: email, password: password);
  }

  Future<void> logout() async {
    await _repo.logout();
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

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(onUnauthorized: () async {
    _unauthorizedNotifier.value++;
  });
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(ref.watch(authRepositoryProvider));
  void listener() => controller.forceUnauthenticated();
  _unauthorizedNotifier.addListener(listener);
  ref.onDispose(() => _unauthorizedNotifier.removeListener(listener));
  return controller;
});
