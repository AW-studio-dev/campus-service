import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(supabaseClientProvider)),
);

final notificationSettingsProvider = FutureProvider<NotificationSettings>((
  ref,
) {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) {
    throw StateError('Une session est nécessaire pour les paramètres.');
  }
  return ref
      .watch(settingsRepositoryProvider)
      .fetchNotificationSettings(userId);
});
