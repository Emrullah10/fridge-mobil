import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../application/household_providers.dart';
import 'household_home_screen.dart';

class HouseholdListScreen extends ConsumerWidget {
  const HouseholdListScreen({super.key});

  Future<void> _createHousehold(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yeni Ev'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Örn. Evimiz'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, nameController.text.trim()),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    await ref.read(householdRepositoryProvider).createHousehold(name);
    ref.invalidate(householdsProvider);
  }

  Future<void> _joinHousehold(BuildContext context, WidgetRef ref) async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Davet Koduyla Katıl'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(hintText: 'Davet kodu'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, codeController.text.trim()),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty) return;
    await ref.read(householdRepositoryProvider).acceptInvite(code);
    ref.invalidate(householdsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdsAsync = ref.watch(householdsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evlerim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış yap',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AsyncView(
        value: householdsAsync,
        data: (households) {
          if (households.isEmpty) {
            return EmptyState(
              icon: Icons.home_outlined,
              message: 'Henüz bir evin yok.\nAşağıdan yeni bir ev oluştur veya davet koduyla katıl.',
              action: FilledButton.icon(
                onPressed: () => _createHousehold(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Ev Oluştur'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl * 2,
            ),
            itemCount: households.length,
            itemBuilder: (context, index) {
              final household = households[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.home_rounded, color: colorScheme.onPrimaryContainer),
                  ),
                  title: Text(household.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Dolaba git'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    ref.read(selectedHouseholdIdProvider.notifier).state = household.id;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => HouseholdHomeScreen(household: household)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join',
            onPressed: () => _joinHousehold(context, ref),
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            elevation: 0,
            icon: const Icon(Icons.group_add_rounded),
            label: const Text('Katıl'),
          ),
          const SizedBox(width: AppSpacing.sm),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () => _createHousehold(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Ev'),
          ),
        ],
      ),
    );
  }
}
