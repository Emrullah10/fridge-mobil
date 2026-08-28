import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/storage_icon_box.dart';
import 'onboarding_mockup.dart';

/// "Bölümler" — üç StorageIconBox sırayla 120ms arayla ölçek+fade ile
/// yerine oturur, ardından bir ürün çipi üstten uçup doğru kutuya girer ve
/// o kutu bir kez nabız atar. Vurgu: storageFridge mavi.
class StorageTilesMockup extends OnboardingMockup {
  const StorageTilesMockup({super.key, required super.active});

  @override
  State<StorageTilesMockup> createState() => _StorageTilesMockupState();
}

class _StorageTilesMockupState extends OnboardingMockupState<StorageTilesMockup> {
  @override
  Duration get animDuration => const Duration(milliseconds: 2400);

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final tiles = [
      (Icons.kitchen_rounded, 'Buzdolabı', appColors.storageFridge),
      (Icons.ac_unit_rounded, 'Dondurucu', appColors.storageFreezer),
      (Icons.inventory_2_rounded, 'Kiler', appColors.storagePantry),
    ];

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        // Çip 0.55 -> 0.8 aralığında üstten hedef kutuya (indeks 0) uçar.
        final flyT = Curves.easeInCubic.transform(((t - 0.55) / 0.25).clamp(0.0, 1.0));
        final chipVisible = t > 0.5 && t < 0.86;
        // Kutu nabzı 0.82 -> 0.94.
        final pulseRaw = ((t - 0.82) / 0.12).clamp(0.0, 1.0);
        final pulse = 1 + 0.08 * (pulseRaw < 0.5 ? pulseRaw * 2 : (1 - pulseRaw) * 2);

        return Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    _tile(i, t, tiles[i], textTheme, scale: i == 0 ? pulse : 1),
                    if (i != tiles.length - 1) const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
              if (chipVisible)
                Positioned(
                  // İlk kutunun yaklaşık x'i: toplam genişlik ~ 3*64 + 2*16 = 224, sol kutu merkezi -80.
                  left: null,
                  top: -70 + flyT * 70,
                  child: Transform.translate(
                    offset: const Offset(-80, 0),
                    child: Opacity(
                      opacity: flyT < 0.9 ? 1 : (1 - flyT) * 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('🥛 Süt', style: textTheme.labelSmall),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(int i, double t, (IconData, String, Color) tile, TextTheme textTheme, {required double scale}) {
    final appear = Curves.easeOutBack.transform(((t - i * 0.12) / 0.3).clamp(0.0, 1.0));
    return Opacity(
      opacity: appear.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: (0.7 + 0.3 * appear).clamp(0.0, 1.0) * scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StorageIconBox(icon: tile.$1, color: tile.$3, size: 64, iconSize: 30),
            const SizedBox(height: AppSpacing.xs),
            Text(tile.$2, style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
