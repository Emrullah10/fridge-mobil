import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/household_repository.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepository(ref.watch(apiClientProvider));
});

// authControllerProvider'ı izler — oturum sahibi değiştiğinde (login/
// register/upgradeAccount/logout/misafir girişi hepsi state'i günceller)
// alan listesi otomatik yeniden çekilir. Bu olmadan önceki kullanıcının
// (özellikle misafirin) alan id'si ekranda kalıyordu; yeni kullanıcı o
// alanın üyesi olmadığı için ilk fiş taramasında backend "Household not
// found" dönüyordu (bkz. .wolf/buglog.json, 2026-09-06 teşhisi).
//
// householdNotFoundNotifier de dinlenir — herhangi bir /households/<id>
// isteği 404 dönerse (bayat/silinmiş alan id'si) liste tazelenir; UI o
// alanın artık listede olmadığını görüp geri döner (bkz. api_client.dart).
final householdsProvider = FutureProvider<List<Household>>((ref) async {
  ref.watch(authControllerProvider);

  void listener() {
    if (householdNotFoundNotifier.value != null) {
      ref.invalidateSelf();
      householdNotFoundNotifier.value = null;
    }
  }

  householdNotFoundNotifier.addListener(listener);
  ref.onDispose(() => householdNotFoundNotifier.removeListener(listener));

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
