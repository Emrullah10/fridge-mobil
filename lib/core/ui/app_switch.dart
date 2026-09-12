import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive.dart';

/// iOS -> CupertinoSwitch, Android -> Switch. `Switch.adaptive` bilerek
/// KULLANILMIYOR — `activeColor` deprecate sürecinde ve Cupertino tarafının
/// davranışı Flutter sürümüne göre değişebiliyor; kendi iki dallı widget'ımız
/// öngörülebilir kalıyor.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    if (isCupertino(context)) {
      return CupertinoSwitch(
        value: value,
        activeTrackColor: activeColor,
        onChanged: onChanged,
      );
    }
    return Switch(
      value: value,
      activeThumbColor: activeColor,
      onChanged: onChanged,
    );
  }
}

/// `SwitchListTile`'ın adaptif karşılığı — başlık/alt açıklama solda,
/// [AppSwitch] sağda.
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: AppSwitch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}
