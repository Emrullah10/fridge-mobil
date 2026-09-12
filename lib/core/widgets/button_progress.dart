import 'package:flutter/material.dart';

import '../ui/app_progress.dart';

/// Dolu buton içindeki yükleniyor göstergesi — 20×20, `onPrimary` rengi.
/// login/register/add_inventory_item/receipt_review ekranlarındaki 4
/// kopyanın (3'ü yanlışlıkla `Colors.white`) yerine geçer. Platforma göre
/// Material/Cupertino spinner seçimi `AppProgress`'te.
class ButtonProgress extends StatelessWidget {
  const ButtonProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return AppProgress(
      size: 20,
      color: Theme.of(context).colorScheme.onPrimary,
    );
  }
}
