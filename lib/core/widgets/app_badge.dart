import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppBadgeVariant { neutral, quantity, warning }

/// Pill rozet — miktar, "Bitti", marka, "Kontrol et" gibi tüm hap
/// rozetlerin tek kaynağı. Radius her zaman tam pill (999).
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.variant = AppBadgeVariant.neutral, this.strikethrough = false});

  final String label;
  final AppBadgeVariant variant;
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (Color background, Color foreground) = switch (variant) {
      AppBadgeVariant.quantity => (colorScheme.secondaryContainer, colorScheme.onSecondaryContainer),
      AppBadgeVariant.warning => (colorScheme.errorContainer, colorScheme.onErrorContainer),
      AppBadgeVariant.neutral => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: foreground,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
