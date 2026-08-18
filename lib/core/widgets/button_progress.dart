import 'package:flutter/material.dart';

/// Dolu buton içindeki yükleniyor göstergesi — 20×20, strokeWidth 2,
/// `onPrimary` rengi. login/register/add_inventory_item/receipt_review
/// ekranlarındaki 4 kopyanın (3'ü yanlışlıkla `Colors.white`) yerine geçer.
class ButtonProgress extends StatelessWidget {
  const ButtonProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}
