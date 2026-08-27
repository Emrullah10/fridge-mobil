import 'package:flutter/material.dart';

import '../../features/insights/presentation/insights_screen.dart';
import '../../features/recipe/presentation/recipes_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shopping/presentation/shopping_list_screen.dart';

/// Alt navigasyon. Alışveriş/Tarifler bir household bağlamı gerektiriyor —
/// `householdId` verilmediği yerlerde (ör. Alanlarım listesi, henüz bir alan
/// seçilmemişken) bu iki sekme navbar'dan tamamen kaldırılır, sadece
/// Alanlarım/Ayarlar kalır. Soluk/tıklanamaz göstermek yerine (kafa karıştırıcı,
/// "neden çalışmıyor" hissi verir) yokluğu netleştirmek tercih edildi —
/// household'a girince navbar 4 sekmeye genişler.
enum AppBottomTab { areas, shopping, recipes, insights, settings }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, this.currentTab = AppBottomTab.areas, this.householdId});

  final AppBottomTab currentTab;
  final String? householdId;

  static const _allItems = [
    (tab: AppBottomTab.areas, icon: Icons.grid_view_rounded, label: 'Alanlarım'),
    (tab: AppBottomTab.shopping, icon: Icons.shopping_cart_rounded, label: 'Alışveriş'),
    (tab: AppBottomTab.recipes, icon: Icons.receipt_long_rounded, label: 'Tarifler'),
    (tab: AppBottomTab.insights, icon: Icons.savings_rounded, label: 'Para'),
    (tab: AppBottomTab.settings, icon: Icons.settings_rounded, label: 'Ayarlar'),
  ];

  // household bağlamı gerektiren sekmeler — alan seçilmeden gösterilmezler
  // (soluk/tıklanamaz göstermek yerine tamamen gizle, cerebrum 2026-08-26).
  static const _householdOnlyTabs = {
    AppBottomTab.shopping,
    AppBottomTab.recipes,
    AppBottomTab.insights,
  };

  List<({AppBottomTab tab, IconData icon, String label})> get _visibleItems {
    if (householdId != null) return _allItems;
    return _allItems.where((item) => !_householdOnlyTabs.contains(item.tab)).toList();
  }

  void _handleTap(BuildContext context, int index) {
    final item = _visibleItems[index];

    if (item.tab == currentTab) {
      // Aynı sekmeye tekrar basmak, o sekmenin köküne döner. Zaten kökteysek
      // (geri gidilecek bir şey yoksa) hiçbir şey yapma.
      if (item.tab == AppBottomTab.areas && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    switch (item.tab) {
      case AppBottomTab.settings:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      case AppBottomTab.shopping:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShoppingListScreen(householdId: householdId!)),
        );
      case AppBottomTab.recipes:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RecipesScreen(householdId: householdId!)),
        );
      case AppBottomTab.insights:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => InsightsScreen(householdId: householdId!)),
        );
      case AppBottomTab.areas:
        // Alanlarım sekmesi: yığın tabanlı navigasyonda "ana ekrana dön"
        // anlamına gelir — en alttaki ekrana kadar geri gidilir.
        Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    final selectedIndex = items.indexWhere((item) => item.tab == currentTab);

    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) => _handleTap(context, index),
      destinations: [
        for (final item in items)
          NavigationDestination(icon: Icon(item.icon), label: item.label),
      ],
    );
  }
}
