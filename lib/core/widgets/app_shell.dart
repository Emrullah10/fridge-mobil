import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/household/application/household_providers.dart';
import '../../features/household/data/household_repository.dart';
import '../../features/household/presentation/household_home_screen.dart';
import '../../features/household/presentation/household_list_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/recipe/presentation/recipes_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shopping/presentation/shopping_list_screen.dart';
import 'app_bottom_nav.dart';

/// Kalıcı navigasyon kabuğu. Eskiden her sekme geçişi bir `Navigator.push`
/// (tam ekran route + sıfırdan Scaffold + tüm provider'ların yeniden fetch
/// edilmesi) demekti — kullanıcı "sayfalar full yeniden başlıyor" diye
/// şikayet etti. Artık sekmeler bir [IndexedStack] içinde birlikte yaşıyor:
/// navbar sabit kalır, yalnızca içerik küçük bir fade+kaydırma animasyonuyla
/// değişir, ekran state'i (scroll, seçili dönem, TabController) korunur.
///
/// İki bağlamda kullanılır:
/// - `const AppShell()` — kök: Alanlarım + Ayarlar (household seçilmemiş).
/// - `AppShell(household: h)` — bir alanın içi: Alan + Alışveriş + Tarifler*
///   + Para + Ayarlar (*yalnızca `household.foodEnabled`).
///
/// Detay ekranları (Envanter, fiş/tarif detayı vb.) shell'in ÜSTÜNE tam ekran
/// push edilir, navbar'sız — yalnızca sekmeler shell içinde kalıcıdır.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key}) : household = null;

  const AppShell.forHousehold(this.household, {super.key});

  final Household? household;

  @override
  ConsumerState<AppShell> createState() => AppShellState();
}

class AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  final Set<int> _built = {0};

  List<AppBottomTabItem> _items(bool? foodEnabled) =>
      visibleTabsFor(householdId: widget.household?.id, foodEnabled: foodEnabled);

  void selectTab(AppBottomTab tab, {required bool? foodEnabled}) {
    final items = _items(foodEnabled);
    final index = items.indexWhere((item) => item.tab == tab);
    if (index < 0 || index == _index) return;
    setState(() {
      _index = index;
      _built.add(index);
    });
  }

  Widget _bodyFor(AppBottomTabItem item) {
    final household = widget.household;
    return switch (item.tab) {
      AppBottomTab.areas => household == null ? const HouseholdListScreen() : HouseholdHomeScreen(household: household),
      AppBottomTab.shopping => ShoppingListScreen(householdId: household!.id),
      AppBottomTab.recipes => RecipesScreen(householdId: household!.id),
      AppBottomTab.insights => InsightsScreen(householdId: household!.id),
      AppBottomTab.settings => const SettingsScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final household = widget.household;
    // household prop'u ile gelen alan bilgisi, o an eski (stale) olabilir —
    // canlı foodEnabled durumu households listesinden okunur (AppBottomNav'ın
    // eski davranışıyla aynı kaynak).
    final liveHousehold = household == null ? null : ref.watch(householdByIdProvider(household.id));
    final foodEnabled = liveHousehold?.foodEnabled ?? household?.foodEnabled;
    final items = _items(foodEnabled);
    final selectedIndex = _index >= items.length ? 0 : _index;

    final content = _AnimatedTabBody(
      index: selectedIndex,
      children: [
        for (var i = 0; i < items.length; i++)
          _built.contains(i) ? _bodyFor(items[i]) : const SizedBox.shrink(),
      ],
    );

    // Alan shell'i: sekme 0 (Alan) dışındayken geri tuşu önce sekme 0'a
    // döner; sekme 0'dayken normal pop (alan listesine çıkar).
    final body = household == null
        ? content
        : PopScope(
            canPop: selectedIndex == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) selectTab(AppBottomTab.areas, foodEnabled: foodEnabled);
            },
            child: content,
          );

    return Scaffold(
      body: body,
      bottomNavigationBar: AppBottomNav(
        key: bottomNavKey,
        items: items,
        selectedIndex: selectedIndex,
        onSelected: (index) {
          if (index == selectedIndex) {
            // Aynı sekmeye tekrar dokunma: Alan/Alanlarım sekmesindeyken o
            // ekranın kendi iç yığınını köküne döndür (ör. Envanter detayından
            // çıkar). Diğer sekmelerde zaten görünür durumda, hiçbir şey yapma.
            return;
          }
          setState(() {
            _index = index;
            _built.add(index);
          });
        },
      ),
    );
  }
}

/// Sekme değişiminde içerik alanına uygulanan küçük fade + yukarı kayma
/// animasyonu — navbar'ın kendisi bu animasyonun dışında, sabit kalır.
class _AnimatedTabBody extends StatefulWidget {
  const _AnimatedTabBody({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_AnimatedTabBody> createState() => _AnimatedTabBodyState();
}

class _AnimatedTabBodyState extends State<_AnimatedTabBody> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.02),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(covariant _AnimatedTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}
