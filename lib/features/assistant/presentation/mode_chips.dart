import 'package:flutter/material.dart';

/// Yemek/Tamir/Genel mod seçimi (bkz. plan §D5). Değişince PATCH
/// /conversations/:id {mode} atılır.
class ModeChips extends StatelessWidget {
  const ModeChips({super.key, required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('food', 'Yemek', Icons.restaurant_rounded),
    ('repair', 'Tamir', Icons.handyman_rounded),
    ('general', 'Genel', Icons.chat_bubble_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        for (final o in _options)
          ButtonSegment(
            value: o.$1,
            label: Text(o.$2),
            icon: Icon(o.$3, size: 16),
          ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
