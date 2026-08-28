import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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

/// Her sekme dolu (seçili) ve çizgi (seçili değil) ikon çiftiyle tanımlanır —
/// seçim animasyonu ikisi arasında geçiş yapar.
typedef AppBottomTabItem = ({AppBottomTab tab, IconData icon, IconData outlinedIcon, String label});

const _allTabItems = <AppBottomTabItem>[
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
    tab: AppBottomTab.recipes,
    icon: Icons.receipt_long_rounded,
    outlinedIcon: Icons.receipt_long_outlined,
    label: 'Tarifler',
  ),
  (
    tab: AppBottomTab.insights,
    icon: Icons.savings_rounded,
    outlinedIcon: Icons.savings_outlined,
    label: 'Para',
  ),
  (
    tab: AppBottomTab.settings,
    icon: Icons.settings_rounded,
    outlinedIcon: Icons.settings_outlined,
    label: 'Ayarlar',
  ),
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

/// Görünür sekme listesi — hem [AppBottomNav] hem coach tour
/// (household_home_screen.dart) bunu kullanır ki sekme sırası/görünürlük
/// kuralı TEK yerde tanımlansın.
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

/// Navbar yüksekliği (güvenli alan hariç). Coach tour'un sekme dikdörtgeni
/// hesabı da bu değere dayanır.
const double kBottomNavHeight = 64;

const _indicatorWidth = 60.0;
const _indicatorHeight = 32.0;
const _animDuration = Duration(milliseconds: 320);
// Göstergenin kendi süresi diğer navbar animasyonlarından (ikon/etiket,
// _animDuration) biraz daha uzun tutulur — daha yavaş/akışkan bir "yağ gibi
// kayma" hissi verir, aksi halde ikonla aynı anda "klik" gibi bitiyordu.
const _indicatorAnimDuration = Duration(milliseconds: 420);

/// Saf sunum bileşeni — navigasyon kararı vermez, seçim [onSelected] ile
/// çağırana bırakılır (bkz. AppShell). Eskiden burada Navigator.push mantığı
/// vardı; her sekme geçişi tam ekran route + sıfırdan state demekti
/// (cerebrum: kullanıcı "sayfalar full yeniden başlıyor" diye şikayet etti).
///
/// Material'ın hazır [NavigationBar]'ı yerine elle çizildi: seçim göstergesi
/// (hap) sekmeler arasında YATAY OLARAK KAYARAK gider, ikon çizgiden doluya
/// dönüşüp hafifçe büyür. NavigationBar'ın kendi göstergesi kaybolup yeniden
/// belirir — kullanıcı hareketin sayfada değil navbar'da olmasını istedi.
///
/// Coach tour (household_home_screen.dart `navTabRect`) bir sekmenin ekran
/// dikdörtgenini spotlight için isteyebilir — `householdShellNavKey.currentState
/// .tabRect(tab)` ile. Dikdörtgen her sekmenin kendi iç GlobalKey'inden
/// ölçülür (aşağıdaki `_tabKeys`); eski "genişlik / sekme sayısı" matematiği
/// SafeArea alt inset'ini işin içine katıp spotlight'ı kaydırıyordu.
class AppBottomNav extends StatefulWidget {
  const AppBottomNav({super.key, required this.items, required this.selectedIndex, required this.onSelected});

  final List<AppBottomTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<AppBottomNav> createState() => AppBottomNavState();
}

class AppBottomNavState extends State<AppBottomNav> with SingleTickerProviderStateMixin {
  // Sekme başına kalıcı key — coach tour'un spotlight dikdörtgeni buradan
  // ölçülür. Key'ler State'in İÇİNDE üretilir: kök shell ve household shell
  // aynı anda canlı olsa bile iki ayrı State, iki ayrı harita → "Duplicate
  // GlobalKey" imkânsız.
  final Map<AppBottomTab, GlobalKey> _tabKeys = {};
  GlobalKey _tabKey(AppBottomTab tab) => _tabKeys.putIfAbsent(tab, GlobalKey.new);

  /// Sekmenin ekran uzayındaki dikdörtgeni; sekme görünür değilse (ör.
  /// foodEnabled=false iken Tarifler) ya da henüz yerleşmediyse null.
  Rect? tabRect(AppBottomTab tab) {
    final box = _tabKeys[tab]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
  late final AnimationController _controller;
  late int _fromIndex;
  late int _toIndex;

  int get _safeIndex =>
      widget.selectedIndex < 0 || widget.selectedIndex >= widget.items.length ? 0 : widget.selectedIndex;

  @override
  void initState() {
    super.initState();
    _fromIndex = _safeIndex;
    _toIndex = _safeIndex;
    _controller = AnimationController(vsync: this, duration: _indicatorAnimDuration)..value = 1;
  }

  @override
  void didUpdateWidget(covariant AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = _safeIndex;
    if (newIndex != _toIndex) {
      _fromIndex = _toIndex;
      _toIndex = newIndex;
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
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kBottomNavHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / widget.items.length;
              return Stack(
                children: [
                  // Kayan/esneyen seçim göstergesi — sekmelerin ALTINDA çizilir
                  // ki ikon/etiket üstünde kalsın. Düz AnimatedPositioned yerine
                  // AnimationController sürüyor: geçiş ortasında hap gitmekte
                  // olduğu yöne doğru uzar (squash & stretch), iki uçta
                  // _indicatorWidth'e toparlanır.
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      // Tek bir yumuşak eğriden (easeInOutCubic) hem konum hem
                      // esneme türetilir — konum ayrı, esneme ayrı eğriyle
                      // gidince hareket "senkronsuz/keskin" hissettiriyordu.
                      final t = Curves.easeInOutCubic.transform(_controller.value);
                      final fromCenter = tabWidth * _fromIndex + tabWidth / 2;
                      final toCenter = tabWidth * _toIndex + tabWidth / 2;
                      final center = fromCenter + (toCenter - fromCenter) * t;

                      // Uçuşun ortasında (tepe noktası t=0.5'te) hap uzar ve
                      // incelir; mesafe arttıkça biraz daha belirgin ama
                      // sınırlı (4+ sekme atlasa bile absürt uzamaz).
                      final distance = (_toIndex - _fromIndex).abs().clamp(0, 2);
                      final flight = math.sin(math.pi * t);
                      final stretch = flight * (10 + distance * 6);
                      final width = _indicatorWidth + stretch;
                      final height = _indicatorHeight - flight * 4;

                      return Positioned(
                        left: center - width / 2,
                        top: (kBottomNavHeight - height) / 2 - 10,
                        width: width,
                        height: height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < widget.items.length; i++)
                        Expanded(
                          child: _NavTab(
                            key: _tabKey(widget.items[i].tab),
                            item: widget.items[i],
                            selected: i == _safeIndex,
                            onTap: () => widget.onSelected(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({super.key, required this.item, required this.selected, required this.onTap});

  final AppBottomTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Seçilince ikon hafifçe büyür ve çizgiden doluya döner.
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: _animDuration,
              curve: Curves.easeOutBack,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  selected ? item.icon : item.outlinedIcon,
                  // AnimatedSwitcher'ın eskiyi/yeniyi ayırt etmesi için key şart.
                  key: ValueKey(selected),
                  size: 24,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AnimatedDefaultTextStyle(
              duration: _animDuration,
              curve: Curves.easeOut,
              style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
