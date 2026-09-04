import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/storage_kind.dart';
import '../data/household_repository.dart';

/// "Yeni Bölüm" / "Bölümü Düzenle" dialogunun sonucu: isim + tür + ikon.
class StorageLocationFormResult {
  const StorageLocationFormResult({
    required this.name,
    required this.kind,
    this.icon,
  });

  final String name;
  final String kind;
  final String? icon;
}

/// Bölüm ekleme/düzenleme dialogu — isim, tür seçimi (Buzdolabı/Depo/Mutfak
/// Dolabı/...) ve serbest ikon seçimi. `existing` verilirse "düzenle" modu.
Future<StorageLocationFormResult?> showStorageLocationFormDialog(
  BuildContext context, {
  StorageLocation? existing,
}) {
  final controller = TextEditingController(text: existing?.name ?? '');
  var selectedKind = existing?.kind ?? storageKindOptions.first.kind;
  var selectedIcon = existing?.icon;

  return showDialog<StorageLocationFormResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        void confirm() {
          if (controller.text.trim().isEmpty) return;
          Navigator.pop(
            dialogContext,
            StorageLocationFormResult(
              name: controller.text.trim(),
              kind: selectedKind,
              icon: selectedIcon,
            ),
          );
        }

        return AlertDialog(
          title: Text(existing == null ? 'Yeni Bölüm' : 'Bölümü Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Örn. Mutfak Dolabı, Depo, Kutu 1',
                  ),
                  autofocus: existing == null,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => confirm(),
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
                    for (final option in storageKindOptions)
                      ChoiceChip(
                        selected: selectedKind == option.kind,
                        onSelected: (_) =>
                            setDialogState(() => selectedKind = option.kind),
                        avatar: Icon(option.icon, size: 18),
                        label: Text(option.label),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'İkon (opsiyonel — boş bırakılırsa türün ikonu kullanılır)',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final iconData in storageIconChoices)
                      ChoiceChip(
                        selected: iconKeyForIcon(iconData) == selectedIcon,
                        onSelected: (selected) => setDialogState(
                          () => selectedIcon = selected
                              ? iconKeyForIcon(iconData)
                              : null,
                        ),
                        label: Icon(iconData, size: 18),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty ? null : confirm,
              child: Text(existing == null ? 'Oluştur' : 'Kaydet'),
            ),
          ],
        );
      },
    ),
  );
}
