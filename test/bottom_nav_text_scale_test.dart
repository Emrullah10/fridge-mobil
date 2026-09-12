import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/core/widgets/app_bottom_nav.dart';

const _items = <AppBottomTabItem>[
  (
    tab: AppBottomTab.areas,
    icon: Icons.grid_view_rounded,
    outlinedIcon: Icons.grid_view_outlined,
    label: 'Alanlarım',
  ),
  (
    tab: AppBottomTab.shopping,
    icon: Icons.shopping_cart_rounded,
    outlinedIcon: Icons.shopping_cart_outlined,
    label: 'Alışveriş',
  ),
  (
    tab: AppBottomTab.settings,
    icon: Icons.settings_rounded,
    outlinedIcon: Icons.settings_outlined,
    label: 'Ayarlar',
  ),
];

void main() {
  testWidgets(
    'navbar en büyük sistem yazı boyutunda (textScale 3.0×) RenderFlex overflow atmaz',
    (tester) async {
      // kBottomNavHeight sabit — _NavTab içindeki MediaQuery.withClampedTextScaling
      // eklenmeden önce iOS AX5 (~3.0×) ölçekte ikon+boşluk+etiket dikeyde
      // taşıyordu (plan Faz D5).
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: AppBottomNav(
                items: _items,
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );
}
