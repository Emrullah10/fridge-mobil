import 'package:flutter/material.dart';

/// Açılış tanıtımındaki dört minyatür maketin ortak taban sınıfı.
///
/// Her maket kendi [AnimationController]'ını tutar ve [active] bayrağını
/// izler: sayfa öne gelince ([active] true) baştan oynar, görünürden
/// çıkınca ([active] false) sıfırlanır. `MediaQuery.disableAnimations`
/// açıkken maket **son karesini statik** gösterir (boş kutu kalmasın) —
/// scan_progress.dart deseni.
abstract class OnboardingMockup extends StatefulWidget {
  const OnboardingMockup({super.key, required this.active});

  /// Bu maketin sayfası şu an ekranda tam görünür mü.
  final bool active;
}

abstract class OnboardingMockupState<T extends OnboardingMockup> extends State<T>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  /// Alt sınıf animasyonun toplam süresini verir.
  Duration get animDuration;

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: animDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncToActive();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _syncToActive();
  }

  void _syncToActive() {
    if (widget.active) {
      if (_reduceMotion) {
        controller.value = 1;
      } else {
        controller
          ..reset()
          ..forward();
      }
    } else {
      if (!_reduceMotion) controller.reset();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
