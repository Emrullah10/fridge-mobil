import 'package:flutter/material.dart';

/// Alan türü (`household.kind`) → ikon + Türkçe etiket. Backend'deki
/// `chk_household_kind` CHECK kısıtıyla (db-schemas/07-storage-kind-text.sql)
/// birebir aynı anahtarları kullanır.
///
/// NOT: Yeni alan oluşturma/düzenleme dialogunda tür seçimi KALDIRILDI —
/// kullanıcı artık serbest bir simge seçiyor (`householdIconChoices`). Bu
/// harita yalnızca ESKİ kayıtların ikon yedeği için duruyor: `features.icon`
/// yoksa alanın eski `kind` değerinin ikonu gösterilir (bir "Ofis" alanı
/// `business_rounded` görünümünü korur).
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
/// Yeni alanlarda dialog varsayılanı KAPALI; bu set yalnızca eski kayıtların
/// yedek türetmesi için gerekli.
const foodKinds = <String>{'home', 'summerhouse', 'cottage', 'dorm', 'boat'};

/// Serbest simge seçimi için sunulan grid — `features['icon']` alanına yazılan
/// kararlı string anahtarlar buradan seçilir. `storage_kind.dart`'taki
/// `storageIconChoices` deseninin household eşi.
const householdIconChoices = <IconData>[
  Icons.home_rounded,
  Icons.business_rounded,
  Icons.beach_access_rounded,
  Icons.cabin_rounded,
  Icons.handyman_rounded,
  Icons.storefront_rounded,
  Icons.apartment_rounded,
  Icons.garage_rounded,
  Icons.directions_boat_rounded,
  Icons.place_rounded,
  Icons.local_florist_rounded,
  Icons.child_friendly_rounded,
  Icons.fitness_center_rounded,
  Icons.pets_rounded,
  Icons.menu_book_rounded,
  Icons.warehouse_rounded,
];

/// `IconData` <-> kararlı string anahtar dönüşümü. Backend `features.icon`
/// kolonuna bu anahtar yazılır (Flutter `IconData.codePoint` sürümler arası
/// kararlı değildir, isim eşlemesi kullanılır). `IconData` `==`/`hashCode`
/// override ettiği için const Map key'i olamıyor — liste küçük, doğrusal
/// eşleme yeterli. (bkz. storage_kind.dart `_iconKeyEntries`.)
const _iconKeyEntries = <(IconData, String)>[
  (Icons.home_rounded, 'home_rounded'),
  (Icons.business_rounded, 'business_rounded'),
  (Icons.beach_access_rounded, 'beach_access_rounded'),
  (Icons.cabin_rounded, 'cabin_rounded'),
  (Icons.handyman_rounded, 'handyman_rounded'),
  (Icons.storefront_rounded, 'storefront_rounded'),
  (Icons.apartment_rounded, 'apartment_rounded'),
  (Icons.garage_rounded, 'garage_rounded'),
  (Icons.directions_boat_rounded, 'directions_boat_rounded'),
  (Icons.place_rounded, 'place_rounded'),
  (Icons.local_florist_rounded, 'local_florist_rounded'),
  (Icons.child_friendly_rounded, 'child_friendly_rounded'),
  (Icons.fitness_center_rounded, 'fitness_center_rounded'),
  (Icons.pets_rounded, 'pets_rounded'),
  (Icons.menu_book_rounded, 'menu_book_rounded'),
  (Icons.warehouse_rounded, 'warehouse_rounded'),
];

String? householdIconKeyForIcon(IconData icon) {
  for (final entry in _iconKeyEntries) {
    if (entry.$1 == icon) return entry.$2;
  }
  return null;
}

IconData? householdIconForKey(String? key) {
  if (key == null) return null;
  for (final entry in _iconKeyEntries) {
    if (entry.$2 == key) return entry.$1;
  }
  return null;
}

/// Bir alanın kartında/AppBar dairesinde gösterilecek ikon. Kademeli yedek:
///  1. Kullanıcının seçtiği serbest simge (`features['icon']` → [iconKey])
///  2. Yoksa eski `kind` değerinin varsayılan ikonu (eski kayıtlar görünümünü
///     kaybetmesin — bir "Ofis" alanı `business_rounded` kalır)
///  3. O da çözülemezse `place_rounded` (`householdKindStyle` orElse → 'home'
///     değil; bilinmeyen kind zaten 'other' → `place_rounded`)
IconData householdIconFor({String? iconKey, required String kind}) {
  return householdIconForKey(iconKey) ?? householdKindStyle(kind).icon;
}
