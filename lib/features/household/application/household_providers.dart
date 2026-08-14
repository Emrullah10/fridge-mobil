import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/household_repository.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepository(ref.watch(apiClientProvider));
});

final householdsProvider = FutureProvider<List<Household>>((ref) async {
  return ref.watch(householdRepositoryProvider).listHouseholds();
});

/// Kullanıcının şu an içinde bulunduğu ev — dolap ve fiş ekranları bunu okur.
final selectedHouseholdIdProvider = StateProvider<String?>((ref) => null);

final storageLocationsProvider = FutureProvider.family<List<StorageLocation>, String>((ref, householdId) async {
  return ref.watch(householdRepositoryProvider).listLocations(householdId);
});
