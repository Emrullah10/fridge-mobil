import 'package:flutter/material.dart';

import '../../features/settings/presentation/settings_screen.dart';

/// Stitch tasarımındaki 4 sekmeli alt navigasyon. "Alanlarım" ve "Ayarlar"
/// gerçek ekranlara gider; Alışveriş/Tarifler uygulamada henüz yok — pasif:
/// dokununca "yakında" snackbar'ı gösterir, sayfa değiştirmez. Giriş sonrası
/// tüm ana ekranlarda (Alanlarım, Alan Ana, Envanter, Ayarlar) gösterilir;
/// form/fiş akışlarında gösterilmez.
enum AppBottomTab { areas, shopping, recipes, settings }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, this.currentTab = AppBottomTab.areas});

  final AppBottomTab currentTab;

  static const _items = [
    (tab: AppBottomTab.areas, icon: Icons.grid_view_rounded, label: 'Alanlarım', enabled: true),
    (tab: AppBottomTab.shopping, icon: Icons.shopping_cart_rounded, label: 'Alışveriş', enabled: false),
    (tab: AppBottomTab.recipes, icon: Icons.receipt_long_rounded, label: 'Tarifler', enabled: false),
    (tab: AppBottomTab.settings, icon: Icons.settings_rounded, label: 'Ayarlar', enabled: true),
  ];

  void _handleTap(BuildContext context, int index) {
    final item = _items[index];

    if (!item.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu özellik yakında eklenecek')),
      );
      return;
    }

    if (item.tab == currentTab) {
      // Aynı sekmeye tekrar basmak, o sekmenin köküne döner. Zaten kökteysek
      // (geri gidilecek bir şey yoksa) hiçbir şey yapma.
      if (item.tab == AppBottomTab.areas && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    if (item.tab == AppBottomTab.settings) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      return;
    }

    // Alanlarım sekmesi: yığın tabanlı navigasyonda "ana ekrana dön" anlamına
    // gelir — en alttaki ekrana kadar geri gidilir (Alanlarım listesi).
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dimColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    final selectedIndex = _items.indexWhere((item) => item.tab == currentTab);

    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) => _handleTap(context, index),
      destinations: [
        for (final item in _items)
          NavigationDestination(
            icon: Icon(item.icon, color: item.enabled ? null : dimColor),
            label: item.label,
            tooltip: item.enabled ? item.label : '${item.label} — yakında',
          ),
      ],
    );
  }
}
