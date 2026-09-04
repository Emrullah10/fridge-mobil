import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/entitlements_repository.dart';
import '../data/purchase_repository.dart';
import '../domain/entitlements.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) => PurchaseRepository());

final entitlementsRepositoryProvider = Provider<EntitlementsRepository>((ref) {
  return EntitlementsRepository(ref.watch(apiClientProvider));
});

/// Entitlements state — cache TTL 5 dakika (plan §Ele alınan diğer uç
/// durumlar: "alan sahipliği değişirse entitlement anında yeniden
/// hesaplanır; mobil cache TTL 5 dakika"). api_client.dart'taki 402
/// interceptor'ı invalidate() çağırır, bu yüzden pratikte kota/plan
/// değişimi genelde anında yansır — TTL sadece arka plan tazeleme sıklığı.
class EntitlementsController extends StateNotifier<AsyncValue<Entitlements>> {
  EntitlementsController(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  final EntitlementsRepository _repo;
  DateTime? _lastFetchedAt;
  static const _cacheTtl = Duration(minutes: 5);

  Future<void> refresh({bool force = false}) async {
    if (!force && _lastFetchedAt != null && DateTime.now().difference(_lastFetchedAt!) < _cacheTtl) {
      return;
    }
    try {
      final entitlements = await _repo.fetch();
      _lastFetchedAt = DateTime.now();
      if (mounted) state = AsyncValue.data(entitlements);
    } catch (error, stack) {
      // Çevrimdışıysa son bilinen değeri koru (plan: "cache yoksa free
      // varsayılır — en cömert değil, AI zaten internet gerektiriyor").
      // state zaten AsyncValue.data ise (önceki başarılı fetch) dokunma;
      // hiç veri yoksa (ilk açılış, çevrimdışı) hataya düş.
      if (mounted && state is! AsyncData) {
        state = AsyncValue.error(error, stack);
      }
    }
  }

  /// 402 interceptor'ı ve satın alma sonrası çağrılır — bir sonraki okuma
  /// TTL'i beklemeden taze veri çeker.
  void invalidate() {
    _lastFetchedAt = null;
    refresh(force: true);
  }
}

final entitlementsControllerProvider =
    StateNotifierProvider<EntitlementsController, AsyncValue<Entitlements>>((ref) {
  // authControllerProvider'ı izler — kullanıcı değişince (login/logout/
  // misafirden yükseltme) entitlements da otomatik yeniden çekilir.
  ref.watch(authControllerProvider);
  final controller = EntitlementsController(ref.watch(entitlementsRepositoryProvider));

  // 402 geldiğinde (api_client.dart'taki interceptor, planLimitNotifier'a
  // yazar) cache'i hemen invalidate et — kullanıcı kotayı doldurduğu anda
  // /me/entitlements TTL'i beklemeden tazelenir, paywall doğru "used/limit"
  // gösterir.
  void listener() {
    if (planLimitNotifier.value != null) controller.invalidate();
  }

  planLimitNotifier.addListener(listener);
  ref.onDispose(() => planLimitNotifier.removeListener(listener));
  return controller;
});

/// Ekranların çoğu sadece son bilinen değeri okumak ister (yükleniyor/hata
/// durumunda UI'ı bloklamadan) — AsyncValue.data(...).value ?? empty deseni
/// her yerde tekrar etmesin diye.
final entitlementsProvider = Provider<Entitlements>((ref) {
  final async = ref.watch(entitlementsControllerProvider);
  return async.value ?? Entitlements.empty;
});
