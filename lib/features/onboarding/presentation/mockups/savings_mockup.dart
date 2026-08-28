import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'onboarding_mockup.dart';

/// "Para" — insights_screen'in stat kartı dili (%10 dolgu + %25 kenarlık).
/// ₺0 → ₺342,50 sayarak artar; altında iki bar (Kurtarılan / İsraf) büyür.
/// Vurgu: storagePantry kehribar + primary.
class SavingsMockup extends OnboardingMockup {
  const SavingsMockup({super.key, required super.active});

  @override
  State<SavingsMockup> createState() => _SavingsMockupState();
}

class _SavingsMockupState extends OnboardingMockupState<SavingsMockup> {
  @override
  Duration get animDuration => const Duration(milliseconds: 1600);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(controller.value);
        final saved = 342.50 * t;
        final wasted = 61.0 * t;

        return Center(
          child: SizedBox(
            width: 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    children: [
                      Text('Bu ay kurtardığın', style: textTheme.bodySmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '₺${saved.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _bar('Kurtarılan', t, colorScheme.primary, '₺${saved.toStringAsFixed(0)}', textTheme, colorScheme),
                const SizedBox(height: AppSpacing.sm),
                _bar('İsraf', wasted / 342.50 * t.clamp(0.0, 1.0), colorScheme.error, '₺${wasted.toStringAsFixed(0)}',
                    textTheme, colorScheme,
                    fullWidthFraction: 0.28),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bar(String label, double fill, Color color, String value, TextTheme textTheme, ColorScheme colorScheme,
      {double fullWidthFraction = 1.0}) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: textTheme.bodySmall)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: (fill * fullWidthFraction).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(value, style: textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}
