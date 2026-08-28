import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Ekranın tamamını karartır, [target] dikdörtgenini (yuvarlatılmış köşeli
/// bir "delik") aydınlık bırakır. Altındaki gerçek arayüz görünür kalır —
/// bu bir ekran görüntüsü değil, canlı widget ağacının üstüne çizilen bir
/// katman. Hedefin çevresinde [pulse] (0..1) ile nabız atan bir halka
/// "buraya dokun" davetini kurar.
class SpotlightPainter extends CustomPainter {
  SpotlightPainter({
    required this.target,
    required this.pulse,
    required this.accent,
    required this.scrimColor,
  });

  final Rect target;
  final double pulse;
  final Color accent;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final inflated = target.inflate(10);
    final holeRRect = RRect.fromRectAndRadius(inflated, const Radius.circular(AppRadius.card));

    final scrimPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(holeRRect),
    );
    canvas.drawPath(scrimPath, Paint()..color = scrimColor);

    // Nabız halkası: hedefin biraz dışında, alfa 0.6 -> 0.
    final ringInset = 4 + 10 * pulse;
    final ringRRect = RRect.fromRectAndRadius(
      inflated.inflate(ringInset),
      const Radius.circular(AppRadius.card + 6),
    );
    canvas.drawRRect(
      ringRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: (0.6 * (1 - pulse)).clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter old) =>
      old.target != target || old.pulse != pulse || old.accent != accent || old.scrimColor != scrimColor;
}
