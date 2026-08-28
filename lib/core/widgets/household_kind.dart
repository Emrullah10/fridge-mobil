import 'package:flutter/material.dart';

/// Alan türü (`household.kind`) → ikon + Türkçe etiket. Backend'deki
/// `chk_household_kind` CHECK kısıtıyla (db-schemas/07-storage-kind-text.sql)
/// birebir aynı anahtarları kullanır.
///
/// Alan "ev" olmak zorunda değil — ofis, yazlık, atölye, dükkan, yurt de
/// olabilir; bu yüzden arayüzde "Alanlarım" terminolojisi kullanılır.
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
  HouseholdKindStyle(kind: 'cottage', icon: Icons.cabin_rounded, label: 'Dağ/Bağ Evi'),
  HouseholdKindStyle(kind: 'workshop', icon: Icons.handyman_rounded, label: 'Atölye'),
  HouseholdKindStyle(kind: 'shop', icon: Icons.storefront_rounded, label: 'Dükkan'),
  HouseholdKindStyle(kind: 'dorm', icon: Icons.apartment_rounded, label: 'Yurt'),
  HouseholdKindStyle(kind: 'garage', icon: Icons.garage_rounded, label: 'Garaj'),
  HouseholdKindStyle(kind: 'boat', icon: Icons.directions_boat_rounded, label: 'Tekne'),
  HouseholdKindStyle(kind: 'other', icon: Icons.place_rounded, label: 'Diğer'),
];

// firstWhere + orElse: sunucu istemciden önce yeni bir tür gönderirse
// (henüz güncellenmemiş eski istemcide) çökmeden "Ev"e düşer.
HouseholdKindStyle householdKindStyle(String kind) {
  return householdKinds.firstWhere(
    (style) => style.kind == kind,
    orElse: () => householdKinds.first,
  );
}

/// Yemeğin doğal olduğu alan türleri — backend'deki
/// household-profile.js FOOD_KINDS ile birebir aynı liste. Bir alanın
/// household.features['food'] alanı boşsa (kullanıcı hiç karar vermediyse)
/// buradan türetilir — Household.foodEnabled getter'ı bu listeyi kullanır.
const foodKinds = <String>{'home', 'summerhouse', 'cottage', 'dorm', 'boat'};
