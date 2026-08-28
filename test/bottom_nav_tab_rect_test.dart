import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/core/widgets/app_bottom_nav.dart';

const _items = <AppBottomTabItem>[
  (tab: AppBottomTab.areas, icon: Icons.grid_view_rounded, outlinedIcon: Icons.grid_view_outlined, label: 'Alanlarım'),
  (
    tab: AppBottomTab.shopping,
    icon: Icons.shopping_cart_rounded,
    outlinedIcon: Icons.shopping_cart_outlined,
    label: 'Alışveriş',
  ),
  (
    tab: AppBottomTab.insights,
    icon: Icons.savings_rounded,
    outlinedIcon: Icons.savings_outlined,
    label: 'Para',
  ),
  (tab: AppBottomTab.settings, icon: Icons.settings_rounded, outlinedIcon: Icons.settings_outlined, label: 'Ayarlar'),
];

void main() {
  testWidgets(
    'tabRect, SafeArea alt inset\'i olan bir cihazda sekme içeriğinin ortasını verir (spotlight kayması regresyonu)',
    (tester) async {
      final key = GlobalKey<AppBottomNavState>();
      const bottomInset = 34.0; // iPhone home indicator benzeri

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
            child: Scaffold(
              bottomNavigationBar: AppBottomNav(
                key: key,
                items: _items,
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      final rect = key.currentState!.tabRect(AppBottomTab.shopping);
      expect(rect, isNotNull);

      // Sekme içeriği navbar'ın üst kBottomNavHeight (64) px'inde yaşar;
      // SafeArea alt inset'i o kutunun ALTINDA. Eski hesap (Material'ın
      // RenderBox'ı / sekme sayısı) merkezi bottomInset/2 kadar aşağı
      // kaydırıyordu. Doğru merkez, navbar'ın tepe noktasından ~32px aşağıda.
      final screenH = tester.getSize(find.byType(MaterialApp)).height;
      final navTop = screenH - bottomInset - kBottomNavHeight;
      expect(rect!.center.dy, closeTo(navTop + kBottomNavHeight / 2, 4));

      // Ölçülen kutu tam navbar içeriği kadar (64) — SafeArea alt inset'i
      // İÇERMİYOR. Eski hesap Material'ı ölçüyordu → 64 + 34 = 98.
      expect(rect.height, closeTo(kBottomNavHeight, 1));
      expect(rect.center.dy, lessThan(navTop + kBottomNavHeight)); // inset bölgesine taşmıyor

      // İkinci sekme (Alışveriş) yatayda kabaca 1.5/4 genişlik konumunda.
      final screenW = tester.getSize(find.byType(MaterialApp)).width;
      expect(rect.center.dx, closeTo(screenW * 1.5 / 4, 4));
    },
  );

  testWidgets('görünmeyen sekme için tabRect null döner', (tester) async {
    final key = GlobalKey<AppBottomNavState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            key: key,
            items: _items,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    // recipes sekmesi bu listede yok.
    expect(key.currentState!.tabRect(AppBottomTab.recipes), isNull);
  });
}
