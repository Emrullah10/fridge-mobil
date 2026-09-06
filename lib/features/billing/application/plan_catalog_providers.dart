import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/plan_catalog_repository.dart';
import '../domain/plan_catalog.dart';

final planCatalogRepositoryProvider = Provider<PlanCatalogRepository>((ref) {
  return PlanCatalogRepository(ref.watch(apiClientProvider));
});

/// /plans oturum boyu sabit sayılır (env override'ları backend restart
/// gerektirir) — TTL'e gerek yok, tek seferlik FutureProvider yeterli.
/// keepAlive: paywall/ayarlar/onboarding üç ayrı yerden okunuyor, her
/// widget'ta yeniden istek atılmasın.
final planCatalogProvider = FutureProvider<PlanCatalog>((ref) async {
  ref.keepAlive();
  return ref.watch(planCatalogRepositoryProvider).fetch();
});
