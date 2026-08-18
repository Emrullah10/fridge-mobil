import 'package:flutter/material.dart';

/// Alan türü (`household.kind`) → ikon + Türkçe etiket. Backend'deki
/// `household_kind` enum'ıyla birebir aynı anahtarları kullanır
/// (db-schemas/00-extensions-enums.sql).
///
/// Alan "ev" olmak zorunda değil — ofis, yazlık, atölye de olabilir; bu yüzden
/// arayüzde "Alanlarım" terminolojisi kullanılır.
class HouseholdKindStyle {
  const HouseholdKindStyle({required this.kind, required this.icon, required this.label});

  final String kind;
  final IconData icon;
  final String label;
}

const householdKinds = <HouseholdKindStyle>[
  HouseholdKindStyle(kind: 'home', icon: Icons.home_rounded, label: 'Ev'),
  HouseholdKindStyle(kind: 'office', icon: Icons.business_rounded, label: 'Ofis'),
  HouseholdKindStyle(kind: 'summerhouse', icon: Icons.beach_access_rounded, label: 'Yazlık'),
  HouseholdKindStyle(kind: 'other', icon: Icons.place_rounded, label: 'Diğer'),
];

HouseholdKindStyle householdKindStyle(String kind) {
  return householdKinds.firstWhere(
    (style) => style.kind == kind,
    orElse: () => householdKinds.first,
  );
}
