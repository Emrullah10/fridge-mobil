import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kaydırmalı çok sayfalı akışların (fiş tarama adımları, açılış tanıtımı)
/// sayfa göstergesi. Aktif nokta bir hap şekline (20×6) uzar, geçiş 250ms
/// easeOut ile yumuşar — scan_progress.dart'ta doğmuş desen, artık iki
/// yerde kopyalanmasın diye buraya çıkarıldı.
///
/// [progress] kesirli (ör. 1.37) verilirse iki komşu nokta arasında ara
/// değer alır — PageView'ın kaydırma ofsetine bağlanınca noktalar parmakla
/// birlikte akar. Tamsayı verilirse klasik "kademeli" davranışı korur.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.progress,
    this.activeColor,
    this.inactiveColor,
  });

  final int count;
  final double progress;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = activeColor ?? colorScheme.primary;
    final inactive = inactiveColor ?? colorScheme.surfaceContainerHighest;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          _dot(i, active, inactive),
          if (i != count - 1) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }

  Widget _dot(int index, Color active, Color inactive) {
    // Her noktanın "aktiflik" oranı: tam üstündeyken 1, bir komşu
    // uzaklıktayken 0. Kesirli progress'te iki nokta birden kısmen dolu olur.
    final distance = (progress - index).abs().clamp(0.0, 1.0);
    final t = 1.0 - distance;
    final width = 6.0 + 14.0 * t;
    final color = Color.lerp(inactive, active, t)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
