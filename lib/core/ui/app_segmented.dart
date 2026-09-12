import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive.dart';

/// `AppSegmented`'te tek bir seçeneği tanımlar.
class AppSegmentedOption<T> {
  const AppSegmentedOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;

  /// Yalnızca Android (Material `SegmentedButton`) dalında çizilir — iOS'ta
  /// `CupertinoSlidingSegmentedControl` segment başına ikon slotu sunmaz.
  final IconData? icon;
}

/// İki-üç seçenekli, tek seçimli segment kontrolü — iOS'ta
/// `CupertinoSlidingSegmentedControl`, Android'de `SegmentedButton` üretir.
class AppSegmented<T extends Object> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: selected,
        onValueChanged: (value) {
          if (value != null) onChanged(value);
        },
        children: {
          for (final option in options)
            option.value: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(option.label),
            ),
        },
      );
    }

    return SegmentedButton<T>(
      segments: [
        for (final option in options)
          ButtonSegment(
            value: option.value,
            label: Text(option.label),
            icon: option.icon == null ? null : Icon(option.icon, size: 16),
          ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
