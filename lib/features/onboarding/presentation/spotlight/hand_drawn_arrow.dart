import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "Pastelle çizilmiş gibi" bir ok. El çizimi hissi üç şeyden gelir:
/// (1) düz değil hafif kavisli bir quadratic bezier, (2) aynı yol 3 kez
/// üst üste, her seferinde küçük deterministik jitter ve düşük alfa —
/// tebeşir/pastel dokusu bu üst üste binmeden çıkar, (3) uca doğru incelen
/// kalınlık + iki kısa çizgiyle çizilmiş ok başı.
///
/// [from] ve [to] aynı koordinat uzayında (bu widget'ı kaplayan Stack'in
/// yerel uzayı). [progress] (0..1) oku uçtan uca "çizer".
class HandDrawnArrow extends StatelessWidget {
  const HandDrawnArrow({
    super.key,
    required this.from,
    required this.to,
    required this.color,
    this.progress = 1,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArrowPainter(from: from, to: to, color: color, progress: progress),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.from, required this.to, required this.color, required this.progress});

  final Offset from;
  final Offset to;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= 0) return;

    final dir = to - from;
    final len = dir.distance;
    if (len < 1) return;
    final normal = Offset(-dir.dy, dir.dx) / len;
    // Kavis: yol ortasında normale doğru len'in ~%14'ü kadar sapma.
    final control = from + dir * 0.5 + normal * (len * 0.14);
    // İlerlemeye göre bitiş noktası.
    final end = _quad(from, control, to, t);

    for (var pass = 0; pass < 3; pass++) {
      final jitter = normal * ((pass - 1) * 1.2);
      final path = Path()..moveTo(from.dx + jitter.dx, from.dy + jitter.dy);
      const steps = 24;
      for (var i = 1; i <= steps; i++) {
        final st = (i / steps) * t;
        final p = _quad(from, control, to, st) + jitter;
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 3.2 - pass * 0.5
          ..color = color.withValues(alpha: 0.42),
      );
    }

    // Ok başı — yalnızca yol neredeyse tamamlanınca.
    if (t > 0.85) {
      final tangent = (_quad(from, control, to, 1.0) - _quad(from, control, to, 0.92));
      final ang = math.atan2(tangent.dy, tangent.dx);
      const headLen = 14.0;
      const spread = 0.5;
      final headPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.6
        ..color = color.withValues(alpha: 0.7);
      for (final s in [spread, -spread]) {
        final tip = end - Offset(math.cos(ang + s), math.sin(ang + s)) * headLen;
        canvas.drawLine(end, tip, headPaint);
      }
    }
  }

  Offset _quad(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) =>
      old.from != from || old.to != to || old.color != color || old.progress != progress;
}
