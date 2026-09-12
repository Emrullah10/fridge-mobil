import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/ui/app_switch.dart';
import '../application/household_providers.dart';
import '../data/household_repository.dart';

/// Bir alanın kendine özel ayarları — ⋮ menüsündeki "Alan özellikleri"
/// öğesinden açılır. Şimdilik tek bölüm (YEMEK) var; ileride bildirim
/// tercihleri, varsayılan SKT süresi, alan tipi gibi ayarlar buraya eklenir.
/// Görsel dil settings_screen.dart ile aynı: küçük-caps bölüm başlığı +
/// [Card] içinde [SwitchListTile].
class HouseholdSettingsScreen extends ConsumerWidget {
  const HouseholdSettingsScreen({super.key, required this.household});

  final Household household;

  /// Kullanıcının household-profile.js'teki tür varsayımını elle ezmesi —
  /// ör. bir ofis alanında mutfak/tarif özelliklerini sonradan açabilir.
  /// (household_home_screen.dart'taki eski `_toggleFoodFeature`'dan taşındı.)
  Future<void> _toggleFoodFeature(
    BuildContext context,
    WidgetRef ref,
    Household household,
  ) async {
    final enable = !household.foodEnabled;
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Yemek özellikleri',
      message: enable
          ? 'Tarifler, AI Chef ve son kullanma tarihi takibi bu alanda açılsın mı?'
          : 'Tarifler ve AI Chef bu alanda kapatılsın mı? Envanter ve alışveriş listesi etkilenmez.',
      cancelLabel: 'İptal',
      confirmLabel: enable ? 'Aç' : 'Kapat',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(householdRepositoryProvider)
          .updateFoodFeature(household.id, enable);
      ref.invalidate(householdsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // updateFoodFeature sonrası households listesi invalidate edilir — ekran
    // hâlâ açıksa güncel foodEnabled'ı burada yansıtır.
    final live = ref.watch(householdByIdProvider(household.id)) ?? household;

    return Scaffold(
      appBar: AppBar(title: const Text('Alan özellikleri')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              'YEMEK',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Card(
            child: AppSwitchTile(
              value: live.foodEnabled,
              onChanged: (_) => _toggleFoodFeature(context, ref, live),
              leading: Icon(
                live.foodEnabled
                    ? Icons.restaurant_rounded
                    : Icons.restaurant_outlined,
              ),
              title: 'Yemek özellikleri',
              subtitle: 'Tarifler, AI Chef ve son kullanma tarihi takibi',
            ),
          ),
        ],
      ),
    );
  }
}
