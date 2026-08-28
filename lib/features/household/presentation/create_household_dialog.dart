import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/household_kind.dart';

/// "Yeni Alan" dialogunun sonucu: isim + tür + yemek özelliği.
class CreateHouseholdResult {
  const CreateHouseholdResult({required this.name, required this.kind, required this.foodEnabled});

  final String name;
  final String kind;
  final bool foodEnabled;
}

/// Alan oluşturma dialogu — isim alanı + tür seçimi (Ev/Ofis/Yazlık/Diğer) +
/// yemek özelliği anahtarı. Tür, kart avatarındaki ikonu belirler ve
/// backend'e `household.kind` olarak yazılır; yemek anahtarı `foodKinds`
/// listesinden türden türetilir ama kullanıcı elle ezebilir — tür
/// değiştikçe anahtar da otomatik güncellenir, TA Kİ kullanıcı anahtara
/// elle dokunana kadar (o andan sonra bir daha ezilmez).
Future<CreateHouseholdResult?> showCreateHouseholdDialog(BuildContext context) {
  final controller = TextEditingController();
  var selectedKind = householdKinds.first.kind;
  var foodEnabled = foodKinds.contains(selectedKind);
  var userTouchedFood = false;

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
                    onSelected: (_) => setDialogState(() {
                      selectedKind = style.kind;
                      // Kullanıcı anahtara hiç dokunmadıysa tür değişince
                      // varsayılan otomatik güncellenir; dokunduysa kararı
                      // korunur (ör. ofiste bilinçli olarak açık bıraktı).
                      if (!userTouchedFood) foodEnabled = foodKinds.contains(selectedKind);
                    }),
                    avatar: Icon(style.icon, size: 18),
                    label: Text(style.label),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Yemek özellikleri'),
              subtitle: const Text('Tarifler, AI Chef, son kullanma tarihi takibi'),
              value: foodEnabled,
              onChanged: (value) => setDialogState(() {
                foodEnabled = value;
                userTouchedFood = true;
              }),
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
              CreateHouseholdResult(name: controller.text.trim(), kind: selectedKind, foodEnabled: foodEnabled),
            ),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    ),
  );
}
