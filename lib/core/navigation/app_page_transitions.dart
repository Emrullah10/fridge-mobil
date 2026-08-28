import 'package:flutter/material.dart';

/// Tüm sayfa geçişleri için tek nokta — Material "shared axis Z" deseni:
/// gelen sayfa küçükten (0.94) büyüyerek + solarak gelir, giden sayfa
/// hafifçe büyüyüp (1.04) solarak kaybolur. AppTheme._base()'de
/// pageTransitionsTheme olarak takılır, mevcut 22 çıplak MaterialPageRoute
/// çağrısının hiçbirine dokunmadan tüm uygulamayı kapsar.
///
/// Hero geçişleri (bkz. household_list_screen.dart → household_home_screen.dart)
/// bu builder'dan bağımsız çalışır — Flutter Hero uçuşunu route transition'ın
/// üstüne ayrıca bindirir.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const _curve = Curves.easeOutCubic;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incomingScale = Tween<double>(begin: 0.94, end: 1.0)
        .chain(CurveTween(curve: _curve))
        .animate(animation);
    final incomingOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeIn))
        .animate(animation);

    final outgoingScale = Tween<double>(begin: 1.0, end: 1.04)
        .chain(CurveTween(curve: _curve))
        .animate(secondaryAnimation);
    final outgoingOpacity = Tween<double>(begin: 1.0, end: 0.0)
        .chain(CurveTween(curve: Curves.easeIn))
        .animate(secondaryAnimation);

    return FadeTransition(
      opacity: outgoingOpacity,
      child: ScaleTransition(
        scale: outgoingScale,
        child: FadeTransition(
          opacity: incomingOpacity,
          child: ScaleTransition(scale: incomingScale, child: child),
        ),
      ),
    );
  }
}
