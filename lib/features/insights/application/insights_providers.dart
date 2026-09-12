import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/insights_repository.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository(ref.watch(apiClientProvider));
});

/// Seçili dönem — null ise backend içinde bulunulan takvim ayını kullanır.
class InsightsPeriod {
  const InsightsPeriod({required this.householdId, this.from, this.to});
  final String householdId;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InsightsPeriod &&
          other.householdId == householdId &&
          other.from == from &&
          other.to == to);

  @override
  int get hashCode => Object.hash(householdId, from, to);
}

// autoDispose: `InsightsPeriod`'un kimliği `_range`'e bağlı (bkz.
// insights_screen.dart) — dönem her değiştiğinde yeni bir family instance'ı
// doğuyor, autoDispose olmadan eskiler asla temizlenmiyordu.
final householdInsightsProvider = FutureProvider.autoDispose
    .family<HouseholdInsights, InsightsPeriod>((ref, period) async {
      return ref
          .watch(insightsRepositoryProvider)
          .fetch(period.householdId, from: period.from, to: period.to);
    });
