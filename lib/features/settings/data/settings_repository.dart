import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsRepository {
  SettingsRepository(this._client);

  final SupabaseClient _client;

  Future<NotificationSettings> fetchNotificationSettings(String userId) async {
    final row = await _client
        .from('notification_preferences')
        .select(
          'email_messages, email_follows, email_comments, email_reviews, '
          'email_marketing, push_enabled',
        )
        .eq('user_id', userId)
        .maybeSingle();
    return row == null
        ? const NotificationSettings.defaults()
        : NotificationSettings.fromMap(row);
  }

  Future<void> saveNotificationSettings({
    required String userId,
    required NotificationSettings settings,
  }) async {
    await _client.from('notification_preferences').upsert({
      'user_id': userId,
      'email_messages': settings.emailMessages,
      'email_follows': settings.emailFollows,
      'email_comments': settings.emailComments,
      'email_reviews': settings.emailReviews,
      'email_marketing': settings.emailMarketing,
      'push_enabled': settings.pushEnabled,
    }, onConflict: 'user_id');
  }
}

class NotificationSettings {
  const NotificationSettings({
    required this.emailMessages,
    required this.emailFollows,
    required this.emailComments,
    required this.emailReviews,
    required this.emailMarketing,
    required this.pushEnabled,
  });

  const NotificationSettings.defaults()
    : emailMessages = true,
      emailFollows = false,
      emailComments = true,
      emailReviews = true,
      emailMarketing = false,
      pushEnabled = false;

  factory NotificationSettings.fromMap(Map<String, dynamic> row) {
    return NotificationSettings(
      emailMessages: row['email_messages'] as bool? ?? true,
      emailFollows: row['email_follows'] as bool? ?? false,
      emailComments: row['email_comments'] as bool? ?? true,
      emailReviews: row['email_reviews'] as bool? ?? true,
      emailMarketing: row['email_marketing'] as bool? ?? false,
      pushEnabled: row['push_enabled'] as bool? ?? false,
    );
  }

  final bool emailMessages;
  final bool emailFollows;
  final bool emailComments;
  final bool emailReviews;
  final bool emailMarketing;
  final bool pushEnabled;

  NotificationSettings copyWith({
    bool? emailMessages,
    bool? emailFollows,
    bool? emailComments,
    bool? emailReviews,
    bool? emailMarketing,
    bool? pushEnabled,
  }) {
    return NotificationSettings(
      emailMessages: emailMessages ?? this.emailMessages,
      emailFollows: emailFollows ?? this.emailFollows,
      emailComments: emailComments ?? this.emailComments,
      emailReviews: emailReviews ?? this.emailReviews,
      emailMarketing: emailMarketing ?? this.emailMarketing,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}
