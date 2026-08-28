import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/core/widgets/household_kind.dart';

void main() {
  test('householdIconFor: features.icon varsa onu döndürür', () {
    expect(
      householdIconFor(iconKey: 'cabin_rounded', kind: 'other'),
      Icons.cabin_rounded,
    );
  });

  test('householdIconFor: icon yoksa eski kind ikonuna düşer', () {
    expect(
      householdIconFor(iconKey: null, kind: 'office'),
      Icons.business_rounded,
    );
  });

  test('householdIconFor: icon yok + bilinmeyen kind → place_rounded (other)', () {
    expect(
      householdIconFor(iconKey: null, kind: 'other'),
      Icons.place_rounded,
    );
  });

  test('householdIconFor: geçersiz icon anahtarı da kind yedeğine düşer', () {
    expect(
      householdIconFor(iconKey: 'bilinmeyen_ikon', kind: 'home'),
      Icons.home_rounded,
    );
  });

  test('iconKey <-> IconData çift yönlü tutarlı', () {
    for (final icon in householdIconChoices) {
      final key = householdIconKeyForIcon(icon);
      expect(key, isNotNull);
      expect(householdIconForKey(key), icon);
    }
  });
}
