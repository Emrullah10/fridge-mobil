import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'onboarding_mockup.dart';

/// "Alışveriş" — 4 satırlık liste; her satır 350ms arayla işaretlenir
/// (kutu dolar, metin üstü çizili + soluk). Üstte bir ilerleme çubuğu 0→1
/// dolar. Envanterdeki "Bitti" muamelesinin aynısı. Vurgu: storageFreezer.
class ShoppingCheckMockup extends OnboardingMockup {
  const ShoppingCheckMockup({super.key, required super.active});

  @override
  State<ShoppingCheckMockup> createState() => _ShoppingCheckMockupState();
}

class _ShoppingCheckMockupState extends OnboardingMockupState<ShoppingCheckMockup> {
  static const _items = ['Domates', 'Zeytinyağı', 'Yumurta', 'Peynir'];

  @override
  Duration get animDuration => const Duration(milliseconds: 2200);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = context.appColors.storageFreezer;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final checkedCount = (_items.length * ((t - 0.1) / 0.8)).clamp(0.0, _items.length.toDouble());

        return Center(
          child: SizedBox(
            width: 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: (checkedCount / _items.length).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < _items.length; i++) ...[
                  _line(i, checkedCount > i + 0.5, accent, colorScheme, textTheme),
                  if (i != _items.length - 1) const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _line(int i, bool checked, Color accent, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: checked ? accent : Colors.transparent,
            border: Border.all(color: checked ? accent : colorScheme.outline, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: checked ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
            color: checked ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.onSurface,
            decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
          ),
          child: Text(_items[i]),
        ),
      ],
    );
  }
}
