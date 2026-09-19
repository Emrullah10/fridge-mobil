import 'package:flutter/material.dart';

const _modeLabels = <String, String>{
  'food': 'yemek',
  'repair': 'tamir',
  'general': 'genel',
};

/// Uyuşmazlıkta cevabın ÜSTÜNDE nazik bant — MaterialBanner DEĞİL (çok
/// baskın), ince Container + swap ikonu + TextButton (bkz. plan §D5).
/// Basınca PATCH {mode}; mesaj YENİDEN GÖNDERİLMEZ.
class ModeMismatchBanner extends StatelessWidget {
  const ModeMismatchBanner({
    super.key,
    required this.mismatchMode,
    required this.onSwitch,
  });

  final String mismatchMode;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = _modeLabels[mismatchMode] ?? mismatchMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz_rounded, size: 16, color: cs.onSecondaryContainer),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Bu bir $label sorusu gibi',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onSwitch,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text('${label[0].toUpperCase()}${label.substring(1)}\'e geç'),
          ),
        ],
      ),
    );
  }
}
