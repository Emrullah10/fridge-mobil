import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fiş tarama/işleme sürecinin adım göstergesi. Gemini ayrıştırması 55sn+
/// sürebildiği için (bkz. cerebrum "Model geçmişi") kullanıcıya sadece dönen
/// bir çark değil, hangi aşamada olduğunu gösterir.
///
/// `MediaQuery.disableAnimations` açıksa (erişilebilirlik) animasyon
/// sadeleşir — dönen ikon yerine sabit ikon + adım metni gösterilir.
class ScanProgress extends StatefulWidget {
  const ScanProgress({
    super.key,
    required this.steps,
    required this.currentStep,
  });

  /// Sırayla gösterilecek adım etiketleri (ör. ['Fotoğraf okunuyor', ...]).
  final List<String> steps;

  /// 0 tabanlı — `steps` içindeki aktif adımın indeksi.
  final int currentStep;

  @override
  State<ScanProgress> createState() => _ScanProgressState();
}

class _ScanProgressState extends State<ScanProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: disableAnimations
              ? Icon(Icons.sync_rounded, size: 40, color: colorScheme.primary)
              : RotationTransition(
                  turns: _controller,
                  child: Icon(Icons.sync_rounded, size: 40, color: colorScheme.primary),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            widget.steps[widget.currentStep.clamp(0, widget.steps.length - 1)],
            key: ValueKey(widget.currentStep),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.steps.length; i++) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == widget.currentStep ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i <= widget.currentStep
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              if (i != widget.steps.length - 1) const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
      ],
    );
  }
}
