import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(supabaseClientProvider)),
);

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) {
    throw StateError('Une session est nécessaire pour voir les notifications.');
  }
  return ref.watch(notificationRepositoryProvider).fetchNotifications(userId);
});

final unreadNotificationsCountProvider = FutureProvider<int>((ref) {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return Future.value(0);
  return ref
      .watch(notificationRepositoryProvider)
      .countUnreadNotifications(userId);
});
