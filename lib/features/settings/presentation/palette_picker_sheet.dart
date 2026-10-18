import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/palette_providers.dart';
import '../../../core/ui/app_sheet.dart';

/// Premium arka plan paleti seçici. Her seçenek uygulamanın küçük bir
/// önizlemesi: arka plan + kart + navbar tonu birlikte görünür. Seçim anında
/// uygulanır (tema yumuşak geçişle değişir).
class PalettePickerSheet extends ConsumerWidget {
  const PalettePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themePaletteProvider);
    final brightness = Theme.of(context).brightness;

    return AppSheetScaffold(
      title: 'Tema rengi',
      subtitle: 'Arka plan ve kart tonları değişir, marka rengi aynı kalır.',
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.78,
        children: [
          for (final palette in AppPalette.values)
            _PaletteTile(
              palette: palette,
              scheme: palette.applyTo(
                brightness == Brightness.dark
                    ? AppTheme.dark().colorScheme
                    : AppTheme.light().colorScheme,
              ),
              selected: palette == selected,
              onTap: () =>
                  ref.read(themePaletteProvider.notifier).setPalette(palette),
            ),
        ],
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.scheme,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final ColorScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final outline = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.label} tema rengi',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? outline : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: selected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: scheme.primary,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                palette.label,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
