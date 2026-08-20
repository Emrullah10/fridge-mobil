import '../../../core/api/api_client.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.householdId,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? householdId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        data: (json['data'] as Map<String, dynamic>?) ?? const {},
        householdId: json['householdId'] as String?,
        readAt: json['readAt'] != null ? DateTime.parse(json['readAt'] as String) : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class NotificationPreference {
  const NotificationPreference({required this.type, required this.pushEnabled});

  final String type;
  final bool pushEnabled;

  factory NotificationPreference.fromJson(Map<String, dynamic> json) => NotificationPreference(
        type: json['type'] as String,
        pushEnabled: json['pushEnabled'] as bool,
      );
}

class NotificationRepository {
  NotificationRepository(this._client);

  final ApiClient _client;

  Future<(List<AppNotification>, int)> list({int limit = 30, DateTime? before}) async {
    final response = await _client.dio.get(
      '/notifications',
      queryParameters: {
        'limit': limit,
        if (before != null) 'before': before.toIso8601String(),
      },
    );
    final notifications = (response.data['notifications'] as List)
        .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
        .toList();
    final unreadCount = response.data['unreadCount'] as int;
    return (notifications, unreadCount);
  }

  Future<int> markRead({List<String>? ids}) async {
    final response = await _client.dio.post('/notifications/read', data: {if (ids != null) 'ids': ids});
    return response.data['unreadCount'] as int;
  }

  Future<List<NotificationPreference>> listPreferences() async {
    final response = await _client.dio.get('/notifications/preferences');
    return (response.data['preferences'] as List)
        .map((p) => NotificationPreference.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> updatePreference(String type, {required bool pushEnabled}) async {
    await _client.dio.patch('/notifications/preferences/$type', data: {'pushEnabled': pushEnabled});
  }

  Future<void> registerDevice(String token, {String platform = 'android'}) async {
    await _client.dio.post('/devices', data: {'token': token, 'platform': platform});
  }

  Future<void> unregisterDevice(String token) async {
    await _client.dio.delete('/devices/$token');
  }
}
