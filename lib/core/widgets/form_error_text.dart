import 'package:flutter/material.dart';

/// Form ekranlarındaki satır içi hata metni — login/register/
/// add_inventory_item ekranlarındaki 3 kopyanın yerine geçer.
class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
