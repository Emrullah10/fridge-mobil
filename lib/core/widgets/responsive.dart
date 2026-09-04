import 'package:flutter/material.dart';

/// Telefon/tablet kırılım noktaları ve responsive yardımcılar. Uygulama
/// masaüstü NavigationRail düzeni sunmaz — yalnızca telefon ve tablet
/// genişlikleri hedeflenir.
abstract final class Breakpoints {
  static const tablet = 600.0;
}

/// Ekran genişliğine göre ızgara sütun sayısı. Telefonda 2, tablette 3.
int gridColumnsFor(double width) {
  return width >= Breakpoints.tablet ? 3 : 2;
}

/// Form ekranlarının (Giriş/Kayıt/Dolaba Ekle) tablette aşırı genişlememesi
/// için kullanılan üst sınır.
const double formMaxWidth = 480;

bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

/// Form ekranları için ortak scroll sarmalayıcı: dikeyde ÜSTE yaslar (ortada
/// başlamaz, klavye açılınca zıplamaz), yatayda [formMaxWidth]'e kadar
/// ortalar, boş yere dokununca/kaydırınca klavyeyi kapatır.
class AppFormScroll extends StatelessWidget {
  const AppFormScroll({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: formMaxWidth),
          child: child,
        ),
      ),
    );
  }
}
