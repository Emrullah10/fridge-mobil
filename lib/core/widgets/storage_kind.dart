import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bölüm (`kind`) string'inden ikon, renk ve Türkçe etiket döndüren tek
/// kaynak. household_home_screen.dart ve receipt_review_screen.dart'taki
/// kopya `_locationStyles` haritalarının yerine geçer.
///
/// Backend `chk_storage_location_kind` CHECK kısıtıyla (bkz.
/// db-schemas/07-storage-kind-text.sql) birebir aynı anahtarları kapsar.
/// Bilinmeyen bir `kind` (sunucu istemciden önce güncellenmişse) `_ =>`
/// dalına düşer — "Diğer" ikonuyla nazikçe gösterilir, çökmez.
class StorageKindStyle {
  const StorageKindStyle({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;
}

/// Bölüm türü seçici ve ikon kataloğu için sıralı liste — hem `kind`
/// varsayılan ikonunu hem Türkçe etiketi taşır.
class StorageKindOption {
  const StorageKindOption({required this.kind, required this.icon, required this.label});

  final String kind;
  final IconData icon;
  final String label;
}

const storageKindOptions = <StorageKindOption>[
  StorageKindOption(kind: 'fridge', icon: Icons.kitchen_rounded, label: 'Buzdolabı'),
  StorageKindOption(kind: 'freezer', icon: Icons.ac_unit_rounded, label: 'Dondurucu'),
  StorageKindOption(kind: 'pantry', icon: Icons.inventory_2_rounded, label: 'Kiler'),
  StorageKindOption(kind: 'cabinet', icon: Icons.door_sliding_rounded, label: 'Mutfak Dolabı'),
  StorageKindOption(kind: 'drawer', icon: Icons.dns_rounded, label: 'Çekmece'),
  StorageKindOption(kind: 'counter', icon: Icons.countertops_rounded, label: 'Tezgah'),
  StorageKindOption(kind: 'cellar', icon: Icons.warehouse_rounded, label: 'Depo'),
  StorageKindOption(kind: 'box', icon: Icons.inventory_rounded, label: 'Kutu'),
  StorageKindOption(kind: 'shelf', icon: Icons.shelves, label: 'Raf'),
  StorageKindOption(kind: 'wine', icon: Icons.wine_bar_rounded, label: 'Şaraplık'),
  StorageKindOption(kind: 'medicine', icon: Icons.medical_services_rounded, label: 'İlaç Dolabı'),
  StorageKindOption(kind: 'balcony', icon: Icons.balcony_rounded, label: 'Balkon'),
  StorageKindOption(kind: 'garage', icon: Icons.garage_rounded, label: 'Garaj'),
  StorageKindOption(kind: 'other', icon: Icons.category_rounded, label: 'Diğer'),
];

/// Serbest ikon seçimi için sunulan grid — `StorageLocation.icon` alanına
/// yazılan anahtarlar buradan seçilir. `storageKindOptions`'daki ikonların
/// üst kümesi + birkaç ek seçenek.
const storageIconChoices = <IconData>[
  Icons.kitchen_rounded,
  Icons.ac_unit_rounded,
  Icons.inventory_2_rounded,
  Icons.door_sliding_rounded,
  Icons.dns_rounded,
  Icons.countertops_rounded,
  Icons.warehouse_rounded,
  Icons.inventory_rounded,
  Icons.shelves,
  Icons.wine_bar_rounded,
  Icons.medical_services_rounded,
  Icons.balcony_rounded,
  Icons.garage_rounded,
  Icons.category_rounded,
  Icons.deck_rounded,
  Icons.local_grocery_store_rounded,
];

/// `IconData` <-> ikon kataloğundaki kararlı string anahtar dönüşümü.
/// Backend `icon` kolonuna bu anahtar yazılır (Flutter `IconData.codePoint`
/// sürümler arası kararlı değildir, bu yüzden isim eşlemesi kullanılır).
/// `IconData` `==`/`hashCode` override ettiği için const Map key'i olamıyor
/// (const_map_key_not_primitive_equality) — liste küçük olduğundan (16 öğe)
/// doğrusal eşleme yeterli.
const _iconKeyEntries = <(IconData, String)>[
  (Icons.kitchen_rounded, 'kitchen_rounded'),
  (Icons.ac_unit_rounded, 'ac_unit_rounded'),
  (Icons.inventory_2_rounded, 'inventory_2_rounded'),
  (Icons.door_sliding_rounded, 'door_sliding_rounded'),
  (Icons.dns_rounded, 'dns_rounded'),
  (Icons.countertops_rounded, 'countertops_rounded'),
  (Icons.warehouse_rounded, 'warehouse_rounded'),
  (Icons.inventory_rounded, 'inventory_rounded'),
  (Icons.shelves, 'shelves'),
  (Icons.wine_bar_rounded, 'wine_bar_rounded'),
  (Icons.medical_services_rounded, 'medical_services_rounded'),
  (Icons.balcony_rounded, 'balcony_rounded'),
  (Icons.garage_rounded, 'garage_rounded'),
  (Icons.category_rounded, 'category_rounded'),
  (Icons.deck_rounded, 'deck_rounded'),
  (Icons.local_grocery_store_rounded, 'local_grocery_store_rounded'),
];

String? iconKeyForIcon(IconData icon) {
  for (final entry in _iconKeyEntries) {
    if (entry.$1 == icon) return entry.$2;
  }
  return null;
}

IconData? iconForKey(String? key) {
  if (key == null) return null;
  for (final entry in _iconKeyEntries) {
    if (entry.$2 == key) return entry.$1;
  }
  return null;
}

StorageKindStyle storageKindStyle(BuildContext context, String kind, {String? icon}) {
  final colors = context.appColors;
  final base = switch (kind) {
    'fridge' => StorageKindStyle(icon: Icons.kitchen_rounded, color: colors.storageFridge, label: 'Buzdolabı'),
    'freezer' => StorageKindStyle(icon: Icons.ac_unit_rounded, color: colors.storageFreezer, label: 'Dondurucu'),
    'pantry' => StorageKindStyle(icon: Icons.inventory_2_rounded, color: colors.storagePantry, label: 'Kiler'),
    'cabinet' => StorageKindStyle(icon: Icons.door_sliding_rounded, color: colors.storageOther, label: 'Mutfak Dolabı'),
    'drawer' => StorageKindStyle(icon: Icons.dns_rounded, color: colors.storageOther, label: 'Çekmece'),
    'counter' => StorageKindStyle(icon: Icons.countertops_rounded, color: colors.storageOther, label: 'Tezgah'),
    'cellar' => StorageKindStyle(icon: Icons.warehouse_rounded, color: colors.storageOther, label: 'Depo'),
    'box' => StorageKindStyle(icon: Icons.inventory_rounded, color: colors.storageOther, label: 'Kutu'),
    'shelf' => StorageKindStyle(icon: Icons.shelves, color: colors.storageOther, label: 'Raf'),
    'wine' => StorageKindStyle(icon: Icons.wine_bar_rounded, color: colors.storageOther, label: 'Şaraplık'),
    'medicine' => StorageKindStyle(icon: Icons.medical_services_rounded, color: colors.storageOther, label: 'İlaç Dolabı'),
    'balcony' => StorageKindStyle(icon: Icons.balcony_rounded, color: colors.storageOther, label: 'Balkon'),
    'garage' => StorageKindStyle(icon: Icons.garage_rounded, color: colors.storageOther, label: 'Garaj'),
    _ => StorageKindStyle(icon: Icons.category_rounded, color: colors.storageOther, label: 'Diğer'),
  };

  final customIcon = iconForKey(icon);
  if (customIcon == null) return base;
  return StorageKindStyle(icon: customIcon, color: base.color, label: base.label);
}
