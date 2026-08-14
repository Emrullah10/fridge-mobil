import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(apiClientProvider));
});

class InventoryParams {
  const InventoryParams({required this.householdId, this.storageLocationId});
  final String householdId;
  final String? storageLocationId;
}

final inventoryItemsProvider =
    FutureProvider.family<List<InventoryItem>, InventoryParams>((ref, params) async {
  return ref.watch(inventoryRepositoryProvider).listItems(
        params.householdId,
        storageLocationId: params.storageLocationId,
      );
});
