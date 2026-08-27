import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/cook_timer_service.dart';
import '../data/recipe_repository.dart';

/// Tam ekran, kaydırmalı adım adım pişirme modu. Süre içeren adımlarda
/// (step.minutes != null) bir geri sayım başlatılabilir; süre dolunca bir
/// bildirim düşer (CookTimerService). Mutfakta telefon kilitlenmemesi ideal
/// olurdu (wakelock) ama bu paket projede henüz yok — kapsam dışı.
class RecipeStepScreen extends StatefulWidget {
  const RecipeStepScreen({super.key, required this.title, required this.steps});

  final String title;
  final List<RecipeStep> steps;

  @override
  State<RecipeStepScreen> createState() => _RecipeStepScreenState();
}

class _RecipeStepScreenState extends State<RecipeStepScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Adım sırası (step.order) -> o adımın timer durumu.
  final Map<int, _StepTimer> _timers = {};

  @override
  void dispose() {
    _pageController.dispose();
    for (final t in _timers.values) {
      t.dispose();
    }
    super.dispose();
  }

  _StepTimer _timerFor(RecipeStep step) {
    return _timers.putIfAbsent(
      step.order,
      () => _StepTimer(
        totalSeconds: (step.minutes ?? 0) * 60,
        onTick: () => setState(() {}),
        onDone: () {
          CookTimerService.instance.notifyStepDone(stepOrder: step.order, recipeTitle: widget.title);
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Adım ${step.order}: süre doldu')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentPage + 1} / ${widget.steps.length}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                for (var i = 0; i < widget.steps.length; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _currentPage ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.steps.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final step = widget.steps[index];
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Adım ${step.order}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          step.text,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (step.minutes != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _StepTimerControl(timer: _timerFor(step), minutes: step.minutes!),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('Geri'),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _currentPage == widget.steps.length - 1
                        ? () => Navigator.of(context).pop()
                        : () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                            ),
                    child: Text(_currentPage == widget.steps.length - 1 ? 'Bitti' : 'Sonraki'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek bir adımın geri sayım durumu. Widget ağacından bağımsız — sayfa
/// kaydırılınca bile çalışmaya devam eder.
class _StepTimer {
  _StepTimer({required this.totalSeconds, required this.onTick, required this.onDone});

  final int totalSeconds;
  final VoidCallback onTick;
  final VoidCallback onDone;

  Timer? _ticker;
  int remaining = 0;
  bool running = false;
  bool finished = false;

  void start() {
    if (running || finished) return;
    if (remaining == 0) remaining = totalSeconds;
    running = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      remaining--;
      if (remaining <= 0) {
        remaining = 0;
        running = false;
        finished = true;
        _ticker?.cancel();
        onDone();
      } else {
        onTick();
      }
    });
    onTick();
  }

  void pause() {
    running = false;
    _ticker?.cancel();
    onTick();
  }

  void reset() {
    _ticker?.cancel();
    running = false;
    finished = false;
    remaining = 0;
    onTick();
  }

  void dispose() => _ticker?.cancel();
}

class _StepTimerControl extends StatelessWidget {
  const _StepTimerControl({required this.timer, required this.minutes});

  final _StepTimer timer;
  final int minutes;

  String _fmt(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final display = timer.remaining > 0
        ? timer.remaining
        : (timer.finished ? 0 : minutes * 60);
    final frac = timer.totalSeconds == 0 ? 0.0 : (display / timer.totalSeconds);

    return Column(
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: timer.running || timer.finished ? frac : 1.0,
                  strokeWidth: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(timer.finished ? cs.error : cs.primary),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt(display),
                    style: tt.headlineSmall?.copyWith(fontFeatures: const [], fontWeight: FontWeight.w700),
                  ),
                  if (timer.finished)
                    Text('doldu', style: tt.labelSmall?.copyWith(color: cs.error)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!timer.finished)
              FilledButton.tonalIcon(
                onPressed: timer.running ? timer.pause : timer.start,
                icon: Icon(timer.running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
                label: Text(timer.running
                    ? 'Duraklat'
                    : (timer.remaining > 0 ? 'Devam' : '$minutes dk başlat')),
              ),
            if (timer.running || timer.finished || timer.remaining > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: timer.reset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Sıfırla'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
