import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive.dart';

/// Yükleniyor göstergesi — `CircularProgressIndicator` uygulamada 28 yerde
/// kullanılıyordu, `CupertinoActivityIndicator` hiç. iOS'ta Material spinner
/// yerlisiz durur. `isCupertino(context)`'e göre doğru olanı seçer.
///
/// Sabit boyutlu bir alanda (buton içi, küçük ikon yerine) kullanılıyorsa
/// [size] verilir; tam ekran/merkez göstergelerde varsayılan yeterlidir.
class AppProgress extends StatelessWidget {
  const AppProgress({super.key, this.size, this.color, this.strokeWidth = 2});

  final double? size;
  final Color? color;

  /// Yalnızca Material dalında kullanılır — Cupertino'nun kendi çizgi
  /// kalınlığı yoktur.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      final indicator = CupertinoActivityIndicator(
        color: color,
        radius: (size ?? 20) / 2,
      );
      return size == null
          ? indicator
          : SizedBox(width: size, height: size, child: indicator);
    }

    final indicator = CircularProgressIndicator(
      strokeWidth: strokeWidth,
      color: color,
    );
    return size == null
        ? indicator
        : SizedBox(width: size, height: size, child: indicator);
  }
}
