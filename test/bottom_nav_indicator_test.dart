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
    tab: AppBottomTab.recipes,
    icon: Icons.receipt_long_rounded,
    outlinedIcon: Icons.receipt_long_outlined,
    label: 'Tarifler',
  ),
  (tab: AppBottomTab.settings, icon: Icons.settings_rounded, outlinedIcon: Icons.settings_outlined, label: 'Ayarlar'),
];

const _restingIndicatorWidth = 60.0;

double _indicatorWidth(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(
    find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration),
  );
  return box.size.width;
}

void main() {
  testWidgets('seçim göstergesi geçiş sırasında esner, dinlenirken sabit genişliğe döner', (tester) async {
    int selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: AppBottomNav(
              items: _items,
              selectedIndex: selectedIndex,
              onSelected: (i) => setState(() => selectedIndex = i),
            ),
          ),
        ),
      ),
    );

    // Başlangıçta (animasyon yok) gösterge dinlenme genişliğinde olmalı.
    expect(_indicatorWidth(tester), _restingIndicatorWidth);

    // Uzak bir sekmeye geç (0 -> 3): animasyon ortasında esnemeli.
    await tester.tap(find.text('Ayarlar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(_indicatorWidth(tester), greaterThan(_restingIndicatorWidth));

    // Animasyon tamamlanınca tekrar dinlenme genişliğine toparlanmalı.
    await tester.pumpAndSettle();
    expect(_indicatorWidth(tester), _restingIndicatorWidth);
  });
}
