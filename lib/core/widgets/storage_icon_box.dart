import 'package:flutter/material.dart';

/// Bölüm ikon kutusu — tam daire, %15 opak zemin + %100 opak ikon.
/// Stitch tasarımında ikon kutuları 14pt yuvarlatılmış kare yerine tam
/// daire olarak çizilmiştir; bu bileşen o kararı tek yerde uygular.
class StorageIconBox extends StatelessWidget {
  const StorageIconBox({super.key, required this.icon, required this.color, this.size = 48, this.iconSize});

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: iconSize ?? size * 0.5),
    );
  }
}
