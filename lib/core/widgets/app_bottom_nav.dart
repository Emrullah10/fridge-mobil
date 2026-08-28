import 'package:flutter/material.dart';

/// Alt navigasyon. Alışveriş/Tarifler/Para bir household bağlamı gerektiriyor —
/// `householdId` verilmediği yerlerde (ör. Alanlarım listesi, henüz bir alan
/// seçilmemişken) bu sekmeler navbar'dan tamamen kaldırılır, sadece
/// Alanlarım/Ayarlar kalır. Soluk/tıklanamaz göstermek yerine (kafa karıştırıcı,
/// "neden çalışmıyor" hissi verir) yokluğu netleştirmek tercih edildi —
/// household'a girince navbar genişler.
///
/// Tarifler AYRICA alanın `foodEnabled` durumuna bağlı (household-profile.js
/// resolveFeatures ile aynı mantık, bkz. Household.foodEnabled) — bir
/// atölye/dükkan alanında tarif anlamsız. Alışveriş/Para HER alan türünde
/// kalır: envanter ekonomisi yemeğe özgü değil.
enum AppBottomTab { areas, shopping, recipes, insights, settings }

typedef AppBottomTabItem = ({AppBottomTab tab, IconData icon, String label});

const _allTabItems = <AppBottomTabItem>[
  (tab: AppBottomTab.areas, icon: Icons.grid_view_rounded, label: 'Alanlarım'),
  (tab: AppBottomTab.shopping, icon: Icons.shopping_cart_rounded, label: 'Alışveriş'),
  (tab: AppBottomTab.recipes, icon: Icons.receipt_long_rounded, label: 'Tarifler'),
  (tab: AppBottomTab.insights, icon: Icons.savings_rounded, label: 'Para'),
  (tab: AppBottomTab.settings, icon: Icons.settings_rounded, label: 'Ayarlar'),
];

// household bağlamı gerektiren sekmeler — alan seçilmeden gösterilmezler
// (soluk/tıklanamaz göstermek yerine tamamen gizle, cerebrum 2026-08-26).
const _householdOnlyTabs = {
  AppBottomTab.shopping,
  AppBottomTab.recipes,
  AppBottomTab.insights,
};

// Alanın foodEnabled==false olduğu durumda ayrıca gizlenen sekmeler.
const _foodOnlyTabs = {AppBottomTab.recipes};

/// Görünür sekme listesi — hem [AppShell] hem coach tour (household_home_screen.dart)
/// bunu kullanır ki sekme sırası/görünürlük kuralı TEK yerde tanımlansın.
///
/// `householdId == null`: henüz bir alan seçilmemiş (Alanlarım listesi kökü) —
/// yalnızca Alanlarım/Ayarlar. `foodEnabled == null`: household verisi henüz
/// yüklenmedi — mevcut davranış korunur: Tarifler gösterilir, veri gelince
/// gerekirse kaybolur (titreme riski, "özellik aniden kayboldu" yerine
/// "kısa süre fazladan görünüyor" olarak tercih edildi).
List<AppBottomTabItem> visibleTabsFor({String? householdId, bool? foodEnabled}) {
  if (householdId == null) {
    return _allTabItems.where((item) => !_householdOnlyTabs.contains(item.tab)).toList();
  }
  if (foodEnabled == false) {
    return _allTabItems.where((item) => !_foodOnlyTabs.contains(item.tab)).toList();
  }
  return _allTabItems;
}

/// Saf sunum bileşeni — navigasyon kararı vermez, seçim [onSelected] ile
/// çağırana bırakılır (bkz. AppShell). Eskiden burada Navigator.push mantığı
/// vardı; her sekme geçişi tam ekran route + sıfırdan state demekti
/// (cerebrum: kullanıcı "sayfalar full yeniden başlıyor" diye şikayet etti).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.items, required this.selectedIndex, required this.onSelected});

  final List<AppBottomTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: onSelected,
      destinations: [
        for (final item in items)
          NavigationDestination(icon: Icon(item.icon), label: item.label),
      ],
    );
  }
}
