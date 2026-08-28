import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/storage_icon_box.dart';
import 'onboarding_mockup.dart';

/// "Fiş Tara" — bir fiş kartının üstünden tarama ışığı süzülür, ışık
/// geçtikçe satırlar fade + yukarı kayarak belirir, sonunda iki
/// StorageIconBox aşağıya "düşer". Vurgu: primary yeşil.
class ReceiptScanMockup extends OnboardingMockup {
  const ReceiptScanMockup({super.key, required super.active});

  @override
  State<ReceiptScanMockup> createState() => _ReceiptScanMockupState();
}

class _ReceiptScanMockupState extends OnboardingMockupState<ReceiptScanMockup> {
  static const _rows = [
    ('EKMEK', '9,90'),
    ('SÜT', '32,50'),
    ('YOĞURT', '24,00'),
  ];

  @override
  Duration get animDuration => const Duration(milliseconds: 2600);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        // Işık kartın üstünden altına 0.0 -> 0.62 aralığında iner.
        final scanT = Curves.easeInOutCubic.transform((t / 0.62).clamp(0.0, 1.0));
        // Kutular 0.7 -> 1.0 aralığında düşer.
        final dropT = Curves.easeOutBack.transform(((t - 0.7) / 0.3).clamp(0.0, 1.0));

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                child: AspectRatio(
                  aspectRatio: 0.86,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('MİGROS', style: textTheme.labelSmall?.copyWith(letterSpacing: 1.5)),
                              const SizedBox(height: AppSpacing.sm),
                              Container(height: 1, color: colorScheme.outlineVariant),
                              const SizedBox(height: AppSpacing.md),
                              for (var i = 0; i < _rows.length; i++) ...[
                                _row(i, scanT, textTheme, colorScheme),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                            ],
                          ),
                        ),
                        // Tarama ışığı.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: scanT * 190 - 20,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colorScheme.primary.withValues(alpha: 0),
                                  colorScheme.primary.withValues(alpha: 0.35),
                                  colorScheme.primary.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Opacity(
                opacity: dropT.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - dropT) * -24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StorageIconBox(icon: Icons.local_drink_rounded, color: context.appColors.storageFridge, size: 44),
                      const SizedBox(width: AppSpacing.sm),
                      StorageIconBox(icon: Icons.bakery_dining_rounded, color: context.appColors.storagePantry, size: 44),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(int i, double scanT, TextTheme textTheme, ColorScheme colorScheme) {
    // Satır, ışık kendi hizasını geçince belirir.
    final threshold = 0.28 + i * 0.16;
    final appear = ((scanT - threshold) / 0.18).clamp(0.0, 1.0);
    return Opacity(
      opacity: appear,
      child: Transform.translate(
        offset: Offset(0, (1 - appear) * 8),
        child: Row(
          children: [
            Expanded(child: Text(_rows[i].$1, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface))),
            Text('₺${_rows[i].$2}', style: textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
