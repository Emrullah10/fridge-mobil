import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/household_kind.dart';

/// "Yeni Alan" dialogunun sonucu: isim + tür.
class CreateHouseholdResult {
  const CreateHouseholdResult({required this.name, required this.kind});

  final String name;
  final String kind;
}

/// Alan oluşturma dialogu — isim alanı + tür seçimi (Ev/Ofis/Yazlık/Diğer).
/// Tür, kart avatarındaki ikonu belirler ve backend'e `household.kind`
/// olarak yazılır.
Future<CreateHouseholdResult?> showCreateHouseholdDialog(BuildContext context) {
  final controller = TextEditingController();
  var selectedKind = householdKinds.first.kind;

  return showDialog<CreateHouseholdResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Yeni Alan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Örn. Evimiz, Ofis, Yazlık'),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tür',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final style in householdKinds)
                  ChoiceChip(
                    selected: selectedKind == style.kind,
                    onSelected: (_) => setDialogState(() => selectedKind = style.kind),
                    avatar: Icon(style.icon, size: 18),
                    label: Text(style.label),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              CreateHouseholdResult(name: controller.text.trim(), kind: selectedKind),
            ),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    ),
  );
}
