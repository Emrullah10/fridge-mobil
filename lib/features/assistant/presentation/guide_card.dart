import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unit_label.dart';
import '../data/assistant_repository.dart';

/// Kılavuz kartı — adımları 'reply' içinde tekrarlamaz, kendi kartında
/// gösterir. "Tarife kaydet" -> save-guide-as-recipe akışı (bkz. plan §D1,
/// §D6).
class GuideCard extends StatelessWidget {
  const GuideCard({
    super.key,
    required this.guide,
    required this.onSave,
    this.saving = false,
    this.saved = false,
  });

  final AssistantGuide guide;
  final VoidCallback onSave;
  final bool saving;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                guide.kind == 'task'
                    ? Icons.handyman_rounded
                    : Icons.restaurant_rounded,
                size: 18,
                color: cs.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(guide.title, style: tt.titleSmall),
              ),
            ],
          ),
          if (guide.servings != null ||
              guide.prepMinutes != null ||
              guide.cookMinutes != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                if (guide.servings != null)
                  Chip(label: Text('${guide.servings} porsiyon')),
                if (guide.prepMinutes != null || guide.cookMinutes != null)
                  Chip(
                    label: Text(
                      '${(guide.prepMinutes ?? 0) + (guide.cookMinutes ?? 0)} dk',
                    ),
                  ),
              ],
            ),
          ],
          if (guide.materials.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Malzemeler', style: tt.labelMedium),
            const SizedBox(height: 4),
            for (final m in guide.materials)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  m.quantity != null
                      ? '• ${m.name} — ${_qty(m.quantity!)} ${unitShortLabel(m.unit ?? "")}'
                            .trim()
                      : '• ${m.name}',
                  style: tt.bodySmall,
                ),
              ),
          ],
          if (guide.steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Adımlar', style: tt.labelMedium),
            const SizedBox(height: 4),
            for (final s in guide.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${s.order}. ${s.text}${s.minutes != null ? " (${s.minutes} dk)" : ""}',
                  style: tt.bodySmall,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: saved
                ? Chip(
                    avatar: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Tarife kaydedildi'),
                  )
                : TextButton.icon(
                    onPressed: saving ? null : onSave,
                    icon: saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text('Tarife kaydet'),
                  ),
          ),
        ],
      ),
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}
