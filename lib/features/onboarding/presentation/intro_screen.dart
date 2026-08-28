import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_dots.dart';
import '../../auth/presentation/widgets/auth_cta_block.dart';
import '../application/onboarding_providers.dart';
import 'mockups/receipt_scan_mockup.dart';
import 'mockups/savings_mockup.dart';
import 'mockups/shopping_check_mockup.dart';
import 'mockups/storage_tiles_mockup.dart';

/// Uygulama ilk açıldığında (kayıt/giriş yapılmamış + tanıtım görülmemiş)
/// gösterilen tam ekran, kaydırılabilir tanıtım. Dört içerik sayfası +
/// bir CTA sayfası. Arka plan tonu ve parallax, PageController'ın kesirli
/// ofsetinden hesaplanır — kaydırırken renk akar, maket ile metin farklı
/// hızda kayar.
///
/// DESIGN_SPEC §8 "animasyon yok" kuralı burada bilinçli olarak deliniyor
/// (bkz. §8.1 Tanıtım istisnası) — tanıtım bir vitrin yüzeyi, günlük
/// kullanım akışı değil.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final _controller = PageController();
  double _page = 0;

  static const _contentPages = 4;
  static const _totalPages = _contentPages + 1; // + CTA

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _markSeenAndSkip() {
    ref.read(onboardingSeenProvider.notifier).markSeen();
    _controller.animateToPage(
      _totalPages - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_page.round() >= _contentPages - 1) {
      _controller.animateToPage(_totalPages - 1,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  Color _accentFor(int index, AppColors appColors, ColorScheme scheme) {
    switch (index) {
      case 0:
        return scheme.primary;
      case 1:
        return appColors.storageFridge;
      case 2:
        return appColors.storageFreezer;
      case 3:
        return appColors.storagePantry;
      default:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    // Kesirli sayfadan arka plan tonunu tween'le.
    final lower = _page.floor().clamp(0, _totalPages - 1);
    final upper = _page.ceil().clamp(0, _totalPages - 1);
    final frac = _page - lower;
    final lowerAccent = _accentFor(lower, appColors, scheme);
    final upperAccent = _accentFor(upper, appColors, scheme);
    final blendedAccent = Color.lerp(lowerAccent, upperAccent, frac)!;
    // surface'i accent'e doğru %10 karıştır — OPAK bir zemin çıkmalı.
    // Eski hali `Color.lerp(surface, accent.withOpacity(0.10), 1.0)` idi:
    // t=1.0 ikinci rengi ALFASIYLA döndürüyordu → %90 şeffaf Scaffold, altından
    // sistem penceresi rengi sızıyordu (sistem açık + uygulama koyu = beyaz
    // zeminde koyu-tema metinleri = "yazılar kayboluyor").
    final bg = Color.lerp(scheme.surface, blendedAccent, 0.10)!;

    final onLastContent = _page.round() >= _contentPages;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Atla — CTA sayfasında gizlenir.
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: onLastContent ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: TextButton(
                      onPressed: onLastContent ? null : _markSeenAndSkip,
                      child: const Text('Atla'),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                children: [
                  _ContentPage(
                    page: _page,
                    index: 0,
                    title: 'Fiş Tara',
                    body: 'Market fişinin fotoğrafını çek — ürünler, fiyatlarıyla birlikte envanterine kendiliğinden düşsün.',
                    accent: _accentFor(0, appColors, scheme),
                    mockup: ReceiptScanMockup(active: _page.round() == 0),
                  ),
                  _ContentPage(
                    page: _page,
                    index: 1,
                    title: 'Bölümler',
                    body: 'Buzdolabı, dondurucu, kiler — ya da atölyene özel raflar. Her ürün doğru yere otursun.',
                    accent: _accentFor(1, appColors, scheme),
                    mockup: StorageTilesMockup(active: _page.round() == 1),
                  ),
                  _ContentPage(
                    page: _page,
                    index: 2,
                    title: 'Alışveriş',
                    body: 'Eksikleri listeye ekle, markette tek dokunuşla işaretle, dönüşte envantere aktar.',
                    accent: _accentFor(2, appColors, scheme),
                    mockup: ShoppingCheckMockup(active: _page.round() == 2),
                  ),
                  _ContentPage(
                    page: _page,
                    index: 3,
                    title: 'Para',
                    body: 'Ne kadar biriktirdiğini, ne kadar israf ettiğini net gör — ay ay, üye üye.',
                    accent: _accentFor(3, appColors, scheme),
                    mockup: SavingsMockup(active: _page.round() == 3),
                  ),
                  _CtaPage(page: _page, index: 4),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                children: [
                  PageDots(
                    count: _totalPages,
                    progress: _page,
                    activeColor: blendedAccent,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AnimatedOpacity(
                    opacity: onLastContent ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: onLastContent,
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(backgroundColor: blendedAccent),
                          child: Text(_page.round() == _contentPages - 1 ? 'Başla' : 'İleri'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentPage extends StatelessWidget {
  const _ContentPage({
    required this.page,
    required this.index,
    required this.title,
    required this.body,
    required this.accent,
    required this.mockup,
  });

  final double page;
  final int index;
  final String title;
  final String body;
  final Color accent;
  final Widget mockup;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // Bu sayfanın merkeze göre ofseti (-1..1 arası anlamlı).
    final delta = (page - index).clamp(-1.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            flex: 5,
            child: Transform.translate(
              offset: Offset(delta * -40, 0),
              child: mockup,
            ),
          ),
          Expanded(
            flex: 3,
            child: Transform.translate(
              offset: Offset(delta * -80, 0),
              child: Opacity(
                opacity: (1 - delta.abs()).clamp(0.0, 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: textTheme.titleLarge?.copyWith(color: accent), textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      body,
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaPage extends StatelessWidget {
  const _CtaPage({required this.page, required this.index});

  final double page;
  final int index;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final delta = (page - index).clamp(-1.0, 1.0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Transform.translate(
          offset: Offset(delta * -60, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.logo),
                  ),
                  child: Icon(Icons.kitchen_rounded, size: 36, color: colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Fridge', style: textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Dolabındaki, depondaki, atölyendeki her şey tek yerde',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              const AuthCtaBlock(),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
