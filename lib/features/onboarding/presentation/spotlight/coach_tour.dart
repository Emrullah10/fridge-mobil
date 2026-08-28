import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'hand_drawn_arrow.dart';
import 'spotlight_painter.dart';

/// Bir spotlight turu adımı: ekranda halihazırda var olan bir widget'ı
/// [targetKey] ile işaret eder. [targetKey] `null` verilirse (ör. navbar
/// sekmesi gibi kendine GlobalKey verilemeyen bir hedef) [rectResolver}
/// çağrılır — turu barındıran overlay context'i verilir, ekran uzayında
/// bir Rect döndürmesi beklenir.
class CoachStep {
  const CoachStep({
    this.targetKey,
    this.rectResolver,
    required this.title,
    required this.body,
    required this.accent,
  }) : assert(targetKey != null || rectResolver != null);

  final GlobalKey? targetKey;
  final Rect Function(BuildContext overlayContext)? rectResolver;
  final String title;
  final String body;
  final Color accent;
}

/// Turu saydam bir rota olarak açar — altındaki gerçek ekran görünür kalır.
/// [onFinished] tur bittiğinde (son adım geçildi ya da Atla) çağrılır;
/// çağıran taraf burada `markSeen()` yapar.
Future<void> showCoachTour(
  BuildContext context, {
  required List<CoachStep> steps,
  required VoidCallback onFinished,
}) {
  if (steps.isEmpty) {
    onFinished();
    return Future.value();
  }
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, a1, a2) => _CoachTourOverlay(steps: steps, onFinished: onFinished),
    ),
  );
}

class _CoachTourOverlay extends StatefulWidget {
  const _CoachTourOverlay({required this.steps, required this.onFinished});

  final List<CoachStep> steps;
  final VoidCallback onFinished;

  @override
  State<_CoachTourOverlay> createState() => _CoachTourOverlayState();
}

class _CoachTourOverlayState extends State<_CoachTourOverlay> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  int _index = 0;
  Rect? _currentRect;
  Rect? _previousRect;
  late final AnimationController _moveController;

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _moveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveRect(animate: false));
  }

  @override
  void dispose() {
    _pulse.dispose();
    _moveController.dispose();
    super.dispose();
  }

  void _resolveRect({required bool animate}) {
    final step = widget.steps[_index];
    Rect? rect;
    if (step.targetKey != null) {
      final ctx = step.targetKey!.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        rect = offset & box.size;
      }
    } else if (step.rectResolver != null) {
      rect = step.rectResolver!(context);
    }
    rect ??= Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(Offset.zero),
      width: 120,
      height: 48,
    );
    setState(() {
      _previousRect = _currentRect ?? rect;
      _currentRect = rect;
    });
    if (animate && !_reduceMotion) {
      _moveController.forward(from: 0);
    } else {
      _moveController.value = 1;
    }
  }

  void _advance() {
    if (_index >= widget.steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _index++);
    _resolveRect(animate: true);
  }

  void _finish() {
    widget.onFinished();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screen = MediaQuery.sizeOf(context);
    final scrim = Colors.black.withValues(alpha: 0.72);

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _moveController]),
        builder: (context, _) {
          final moveT = Curves.easeOutCubic.transform(_moveController.value);
          final rect = Rect.lerp(_previousRect, _currentRect, moveT) ?? _currentRect ?? Rect.zero;
          final pulseT = _reduceMotion ? 0.0 : Curves.easeOut.transform(_pulse.value);

          // Balon hedefin altına ya da üstüne — ekran ortasının hangi
          // yarısındaysa ona göre.
          final targetBelowMid = rect.center.dy > screen.height / 2;
          // Ok, hedefe balon tarafından yaklaşır (hedef alttaysa yukarıdan iner).
          final arrowFrom = targetBelowMid
              ? Offset(rect.center.dx, rect.top - 90)
              : Offset(rect.center.dx, rect.bottom + 90);
          final arrowTo = targetBelowMid
              ? Offset(rect.center.dx, rect.top - 12)
              : Offset(rect.center.dx, rect.bottom + 12);

          return Stack(
            children: [
              // Karartma + delik + nabız halkası.
              Positioned.fill(
                child: CustomPaint(
                  painter: SpotlightPainter(
                    target: rect,
                    pulse: pulseT,
                    accent: step.accent,
                    scrimColor: scrim,
                  ),
                ),
              ),
              // Hedefe dokunma ilerletir (kullanıcının istediği etkileşim).
              Positioned.fromRect(
                rect: rect.inflate(10),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _advance,
                ),
              ),
              // El çizimi ok.
              Positioned.fill(
                child: IgnorePointer(
                  child: HandDrawnArrow(
                    from: arrowFrom,
                    to: arrowTo,
                    color: Color.lerp(step.accent, Colors.white, 0.35)!,
                    progress: moveT,
                  ),
                ),
              ),
              // Bilgi balonu.
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: targetBelowMid ? null : rect.bottom + 100,
                bottom: targetBelowMid ? screen.height - rect.top + 100 : null,
                child: _Bubble(
                  step: step,
                  index: _index,
                  total: widget.steps.length,
                  scheme: scheme,
                  textTheme: textTheme,
                  onNext: _advance,
                  onSkip: _finish,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.step,
    required this.index,
    required this.total,
    required this.scheme,
    required this.textTheme,
    required this.onNext,
    required this.onSkip,
  });

  final CoachStep step;
  final int index;
  final int total;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.title, style: textTheme.titleSmall?.copyWith(color: step.accent)),
          const SizedBox(height: AppSpacing.xs),
          Text(step.body, style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${index + 1} / $total', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              Row(
                children: [
                  if (!isLast)
                    TextButton(onPressed: onSkip, child: const Text('Atla')),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: step.accent,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    ),
                    child: Text(isLast ? 'Bitti' : 'İleri'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
