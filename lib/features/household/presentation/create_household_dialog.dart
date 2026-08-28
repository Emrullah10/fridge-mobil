import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/household_kind.dart';
import '../data/household_repository.dart';

/// "Yeni Alan" / "Alanı Düzenle" dialogunun sonucu: isim + serbest simge +
/// yemek özelliği (yemek yalnızca oluşturma modunda anlamlı).
class HouseholdFormResult {
  const HouseholdFormResult({required this.name, this.icon, required this.foodEnabled});

  final String name;
  final String? icon;
  final bool foodEnabled;
}

/// Alan oluşturma/düzenleme dialogu. `existing` verilirse "düzenle" modu:
/// başlık "Alanı Düzenle", buton "Kaydet", yemek switch'i gizli (o ayarın
/// tek yeri Alan Özellikleri ekranı). İsim zorunlu — boşsa inline hata,
/// dialog kapanmaz.
Future<HouseholdFormResult?> showHouseholdFormDialog(
  BuildContext context, {
  Household? existing,
}) {
  final isEdit = existing != null;
  final controller = TextEditingController(text: existing?.name ?? '');
  // Oluşturmada varsayılan seçili simge; düzenlemede mevcut simge (yoksa yine
  // ilk seçenek — "seçimsiz" durumu yok, kart hiç ikonsuz kalmaz).
  var selectedIcon = existing?.icon ?? householdIconKeyForIcon(householdIconChoices.first);
  var foodEnabled = false;
  String? nameError;

  return showDialog<HouseholdFormResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(isEdit ? 'Alanı Düzenle' : 'Yeni Alan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Örn. Evimiz, Ofis, Yazlık, Sığınak',
                  errorText: nameError,
                ),
                autofocus: !isEdit,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (nameError != null) setDialogState(() => nameError = null);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Simge', style: Theme.of(dialogContext).textTheme.bodySmall),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final iconData in householdIconChoices)
                    ChoiceChip(
                      selected: householdIconKeyForIcon(iconData) == selectedIcon,
                      onSelected: (_) => setDialogState(
                        () => selectedIcon = householdIconKeyForIcon(iconData),
                      ),
                      label: Icon(iconData, size: 18),
                    ),
                ],
              ),
              if (!isEdit) ...[
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yemek özellikleri'),
                  subtitle: const Text('Tarifler, AI Chef, son kullanma tarihi takibi'),
                  value: foodEnabled,
                  onChanged: (value) => setDialogState(() => foodEnabled = value),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                setDialogState(() => nameError = 'Bir isim girin');
                return;
              }
              Navigator.pop(
                dialogContext,
                HouseholdFormResult(name: name, icon: selectedIcon, foodEnabled: foodEnabled),
              );
            },
            child: Text(isEdit ? 'Kaydet' : 'Oluştur'),
          ),
        ],
      ),
    ),
  );
}
