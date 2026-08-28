import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/household_repository.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepository(ref.watch(apiClientProvider));
});

final householdsProvider = FutureProvider<List<Household>>((ref) async {
  return ref.watch(householdRepositoryProvider).listHouseholds();
});

/// Tek bir alanı listeden türetir — ek ağ isteği atmaz. `householdsProvider`
/// zaten tüm alanları taşıyor, AppBottomNav gibi tek bir alanın
/// `foodEnabled` durumuna ihtiyaç duyan yerler bunu kullanır.
final householdByIdProvider = Provider.family<Household?, String?>((ref, householdId) {
  if (householdId == null) return null;
  final households = ref.watch(householdsProvider).valueOrNull;
  if (households == null) return null;
  for (final household in households) {
    if (household.id == householdId) return household;
  }
  return null;
});

/// Kullanıcının şu an içinde bulunduğu ev — dolap ve fiş ekranları bunu okur.
final selectedHouseholdIdProvider = StateProvider<String?>((ref) => null);

final storageLocationsProvider = FutureProvider.family<List<StorageLocation>, String>((ref, householdId) async {
  return ref.watch(householdRepositoryProvider).listLocations(householdId);
});

final householdMembersProvider = FutureProvider.family<List<HouseholdMember>, String>((ref, householdId) async {
  return ref.watch(householdRepositoryProvider).listMembers(householdId);
});
