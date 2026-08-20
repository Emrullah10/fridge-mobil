import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'member_joined':
        return Icons.group_add_rounded;
      case 'item_expiring':
        return Icons.event_busy_rounded;
      case 'receipt_processed':
        return Icons.receipt_long_rounded;
      case 'item_consumed':
        return Icons.remove_shopping_cart_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return DateFormat('dd.MM.yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(notificationListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          if ((stateAsync.valueOrNull?.unreadCount ?? 0) > 0)
            TextButton(
              onPressed: () => ref.read(notificationListProvider.notifier).markAllRead(),
              child: const Text('Hepsini okundu işaretle'),
            ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 48, color: colorScheme.error),
                const SizedBox(height: AppSpacing.md),
                Text(describeApiError(error), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => ref.read(notificationListProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Yeniden dene'),
                ),
              ],
            ),
          ),
        ),
        data: (state) {
          if (state.notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              message: 'Henüz bildirimin yok.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: state.notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = state.notifications[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: notification.isRead
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.primaryContainer,
                    child: Icon(
                      _iconForType(notification.type),
                      color: notification.isRead ? colorScheme.onSurfaceVariant : colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w700),
                  ),
                  subtitle: Text(notification.body),
                  trailing: Text(
                    _relativeTime(notification.createdAt),
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                  onTap: notification.isRead
                      ? null
                      : () => ref.read(notificationRepositoryProvider).markRead(ids: [notification.id]).then(
                            (_) => ref.read(notificationListProvider.notifier).refresh(),
                          ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
