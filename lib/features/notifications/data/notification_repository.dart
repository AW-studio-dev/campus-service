import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> fetchNotifications(String userId) async {
    final rows = await _client
        .from('notifications')
        .select('id, type, payload, read_at, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows
        .map(
          (row) => AppNotification(
            id: row['id'] as String,
            type: row['type'] as String,
            payload: row['payload'] as Map<String, dynamic>? ?? const {},
            isRead: row['read_at'] != null,
            createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          ),
        )
        .toList();
  }

  Future<void> markAsRead(String notificationId, String userId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;
}
