import 'package:flutter/material.dart';

/// Tarif kartında "8/10 malzeme var" dairesel göstergesi. Renk: tüm zorunlu
/// malzemeler varsa yeşil (primary), 1-2 eksikse amber (statusWarning), daha
/// fazlası eksikse nötr gri.
class RecipeMatchRing extends StatelessWidget {
  const RecipeMatchRing({
    super.key,
    required this.available,
    required this.total,
    this.size = 44,
  });

  final int available;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = total == 0 ? 1.0 : available / total;
    final missing = total - available;

    final color = missing == 0
        ? colorScheme.primary
        : missing <= 2
            ? const Color(0xFFB45309)
            : colorScheme.onSurfaceVariant;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$available/$total',
            style: TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
