import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/notification_repository.dart';
import '../data/push_service.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(ref.watch(notificationRepositoryProvider));
});

class NotificationListState {
  const NotificationListState({
    required this.notifications,
    required this.unreadCount,
    this.isLoading = false,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationListState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) =>
      NotificationListState(
        notifications: notifications ?? this.notifications,
        unreadCount: unreadCount ?? this.unreadCount,
        isLoading: isLoading ?? this.isLoading,
      );
}

/// AppBar zil ikonu + bildirim ekranı bu tek state'i paylaşır — biri
/// okundu işaretlerse diğeri de anında güncellensin diye.
class NotificationListNotifier extends StateNotifier<AsyncValue<NotificationListState>> {
  NotificationListNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  final NotificationRepository _repo;

  Future<void> refresh() async {
    try {
      final (notifications, unreadCount) = await _repo.list();
      state = AsyncValue.data(NotificationListState(notifications: notifications, unreadCount: unreadCount));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final unreadCount = await _repo.markRead();
    state = AsyncValue.data(
      current.copyWith(
        unreadCount: unreadCount,
        notifications: [for (final n in current.notifications) _markedRead(n)],
      ),
    );
  }

  AppNotification _markedRead(AppNotification n) => AppNotification(
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        householdId: n.householdId,
        readAt: n.readAt ?? DateTime.now(),
        createdAt: n.createdAt,
      );
}

final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, AsyncValue<NotificationListState>>((ref) {
  return NotificationListNotifier(ref.watch(notificationRepositoryProvider));
});
