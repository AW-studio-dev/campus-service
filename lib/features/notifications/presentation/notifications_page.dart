import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/social_card.dart';
import '../application/notification_providers.dart';
import '../data/notification_repository.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id ?? '';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: () => ref.invalidate(notificationsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: notifications.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Impossible de charger les notifications.'),
                  TextButton(
                    onPressed: () => ref.invalidate(notificationsProvider),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text(
                      'Vous n’avez aucune notification pour le moment.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final previousDate = index == 0
                          ? null
                          : _dateLabel(items[index - 1].createdAt);
                      final currentDate = _dateLabel(item.createdAt);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (currentDate != previousDate)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                              child: Text(
                                currentDate,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          SocialCard(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              leading: AppAvatar(
                                name: item.payload['actor_name'] as String?,
                              ),
                              tileColor: item.isRead
                                  ? null
                                  : AppColors.primary.withValues(alpha: 0.04),
                              title: Text(_notificationText(item)),
                              subtitle: Text(_timeLabel(item.createdAt)),
                              onTap: item.isRead
                                  ? null
                                  : () async {
                                      try {
                                        final clientUserId = ref.read(
                                          notificationRepositoryProvider,
                                        );
                                        await clientUserId.markAsRead(
                                          item.id,
                                          userId,
                                        );
                                        ref.invalidate(notificationsProvider);
                                      } on Exception {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Impossible de marquer la '
                                                  'notification comme lue.',
                                                ),
                                              ),
                                            );
                                        }
                                      }
                                    },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _notificationText(AppNotification item) {
    final actor = item.payload['actor_name'] as String?;
    final name = actor == null || actor.trim().isEmpty ? 'Un étudiant' : actor;
    return switch (item.type) {
      'new_message' => '$name vous a envoyé un message.',
      'new_follower' => '$name a commencé à vous suivre.',
      'new_comment' => '$name a commenté votre publication.',
      'new_reaction' => '$name a réagi à votre publication.',
      'new_review' => 'Vous avez reçu un nouvel avis.',
      'new_request_response' => 'Votre demande a reçu une réponse.',
      'moderation_event' => 'Une mise à jour de modération est disponible.',
      _ => item.payload['message'] as String? ?? 'Nouvelle notification.',
    };
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Aujourd’hui';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Hier';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _timeLabel(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
