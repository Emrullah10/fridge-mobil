import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/widgets/async_view.dart';
import '../../auth/application/auth_providers.dart';
import '../application/household_providers.dart';
import '../data/household_repository.dart';

const _roleLabels = {
  'owner': 'Sahip',
  'admin': 'Yönetici',
  'member': 'Üye',
  'viewer': 'İzleyici',
};

/// Alandaki üyeleri listeler. Sahip için alanı silme, diğer üyeler için
/// alandan ayrılma seçeneği burada sunulur (kullanıcı kararı: sadece sahip
/// silebilir, herkes ayrılabilir).
class HouseholdMembersScreen extends ConsumerWidget {
  const HouseholdMembersScreen({super.key, required this.household});

  final Household household;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Alandan ayrıl',
      message: '${household.name} alanından ayrılmak istediğine emin misin?',
      confirmLabel: 'Ayrıl',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(householdRepositoryProvider).leaveHousehold(household.id);
      ref.invalidate(householdsProvider);
      if (context.mounted) {
        // Alan artık listede yok — üye ekranından da geriye dön.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Alanı sil',
      message:
          '${household.name} alanı ve içindeki TÜM envanter, fiş ve üyelik verisi '
          'kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      confirmLabel: 'Alanı sil',
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(householdRepositoryProvider).deleteHousehold(household.id);
      ref.invalidate(householdsProvider);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(householdMembersProvider(household.id));
    final currentUserId = ref.watch(authControllerProvider).user?.id;
    final dateFormat = DateFormat('dd.MM.yyyy');
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Üyeler')),
      body: AsyncView(
        value: membersAsync,
        onRetry: () => ref.invalidate(householdMembersProvider(household.id)),
        data: (members) {
          final isOwner = members.any((m) => m.userId == currentUserId && m.role == 'owner');
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final member in members)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
                        style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(member.displayName),
                    subtitle: Text('${member.email} · ${dateFormat.format(member.joinedAt.toLocal())} katıldı'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        _roleLabels[member.role] ?? member.role,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              if (isOwner)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
                  onPressed: () => _delete(context, ref),
                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                  label: const Text('Alanı sil'),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
                  onPressed: () => _leave(context, ref),
                  icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                  label: const Text('Alandan ayrıl'),
                ),
            ],
          );
        },
      ),
    );
  }
}
