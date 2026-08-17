import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mobil/features/inventory/application/inventory_providers.dart';

void main() {
  test('InventoryParams equality is value-based', () {
    const a = InventoryParams(householdId: 'h1', storageLocationId: 's1');
    const b = InventoryParams(householdId: 'h1', storageLocationId: 's1');
    const c = InventoryParams(householdId: 'h1', storageLocationId: 's2');

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a == c, isFalse);
  });
}
