import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/household_kind.dart';
import '../../../core/widgets/single_field_dialog.dart';
import '../../auth/application/auth_providers.dart';
import '../application/household_providers.dart';
import 'create_household_dialog.dart';
import 'household_home_screen.dart';

class HouseholdListScreen extends ConsumerWidget {
  const HouseholdListScreen({super.key});

  Future<void> _createHousehold(BuildContext context, WidgetRef ref) async {
    final result = await showCreateHouseholdDialog(context);

    if (result == null || result.name.isEmpty) return;
    try {
      await ref.read(householdRepositoryProvider).createHousehold(result.name, kind: result.kind);
      ref.invalidate(householdsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  Future<void> _joinHousehold(BuildContext context, WidgetRef ref) async {
    final code = await showSingleFieldDialog(
      context,
      title: 'Davet Koduyla Katıl',
      hintText: 'Davet kodu',
      confirmLabel: 'Katıl',
    );

    if (code == null || code.isEmpty) return;
    try {
      await ref.read(householdRepositoryProvider).acceptInvite(code);
      ref.invalidate(householdsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdsAsync = ref.watch(householdsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alanlarım'),
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
        onRetry: () => ref.invalidate(householdsProvider),
        data: (households) {
          if (households.isEmpty) {
            return EmptyState(
              icon: Icons.home_outlined,
              message: 'Henüz bir alanın yok.\nAşağıdan yeni bir alan oluştur veya davet koduyla katıl.',
              action: FilledButton.icon(
                onPressed: () => _createHousehold(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Alan Oluştur'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.fabBottomPadding,
            ),
            itemCount: households.length,
            itemBuilder: (context, index) {
              final household = households[index];
              final kindStyle = householdKindStyle(household.kind);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(kindStyle.icon, color: colorScheme.onPrimaryContainer),
                  ),
                  title: Text(household.name, style: textTheme.titleSmall),
                  subtitle: Text(kindStyle.label),
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
      bottomNavigationBar: const AppBottomNav(currentTab: AppBottomTab.areas),
      floatingActionButton: Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpacing.sm,
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
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () => _createHousehold(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Alan'),
          ),
        ],
      ),
    );
  }
}
