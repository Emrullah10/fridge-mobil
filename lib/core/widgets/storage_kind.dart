import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bölüm (`kind`) string'inden ikon, renk ve Türkçe etiket döndüren tek
/// kaynak. household_home_screen.dart ve receipt_review_screen.dart'taki
/// kopya `_locationStyles` haritalarının yerine geçer.
class StorageKindStyle {
  const StorageKindStyle({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;
}

StorageKindStyle storageKindStyle(BuildContext context, String kind) {
  final colors = context.appColors;
  return switch (kind) {
    'fridge' => StorageKindStyle(icon: Icons.kitchen_rounded, color: colors.storageFridge, label: 'Buzdolabı'),
    'freezer' => StorageKindStyle(icon: Icons.ac_unit_rounded, color: colors.storageFreezer, label: 'Dondurucu'),
    'pantry' => StorageKindStyle(icon: Icons.inventory_2_rounded, color: colors.storagePantry, label: 'Kiler'),
    _ => StorageKindStyle(icon: Icons.category_rounded, color: colors.storageOther, label: 'Diğer'),
  };
}
