import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/social_card.dart';
import '../application/notification_providers.dart';
import '../data/notification_repository.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _isMarkingAll = false;

  Future<void> _markAsRead(AppNotification item) async {
    if (item.isRead) return;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    try {
      await ref
          .read(notificationRepositoryProvider)
          .markAsRead(item.id, userId);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } on Exception {
      // La navigation reste possible même si le marquage échoue.
    }
  }

  Future<void> _openNotification(AppNotification item) async {
    await _markAsRead(item);
    if (!mounted) return;
    final route = _targetRoute(item);
    if (route != null) {
      context.go(route);
    }
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAll) return;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isMarkingAll = true);
    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead(userId);
      if (!mounted) return;
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de marquer les notifications comme lues.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  /// Destination associée à une notification. `null` signifie que l'élément
  /// n'a pas de page dédiée : on se contente alors de le marquer comme lu.
  String? _targetRoute(AppNotification item) {
    final payload = item.payload;
    final actorId = payload['actor_id'];
    final businessId = payload['business_id'];
    final conversationId = payload['conversation_id'];
    switch (item.type) {
      case 'new_message':
        return conversationId is String && conversationId.isNotEmpty
            ? '/chat/$conversationId'
            : '/messages';
      case 'new_follower':
      case 'new_comment':
      case 'new_reaction':
        return actorId is String && actorId.isNotEmpty
            ? '/profile/$actorId'
            : null;
      case 'new_review':
        return businessId is String && businessId.isNotEmpty
            ? '/business/$businessId'
            : null;
      case 'new_request_response':
        return '/profile?tab=requests';
      case 'moderation_event':
        return '/settings';
      case 'system':
        if (payload['kind'] == 'new_post' &&
            actorId is String &&
            actorId.isNotEmpty) {
          return '/profile/$actorId';
        }
        return null;
      default:
        return null;
    }
  }

  String? _actorAvatarUrl(Map<String, dynamic> payload) {
    final path = payload['actor_avatar_path'] as String?;
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return ref
        .read(supabaseClientProvider)
        .storage
        .from('avatars')
        .getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
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
              TextButton.icon(
                onPressed: _isMarkingAll ? null : _markAllAsRead,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Tout lire'),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: () {
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadNotificationsCountProvider);
                },
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
                                imageUrl: _actorAvatarUrl(item.payload),
                                name: _actorName(item.payload),
                              ),
                              tileColor: item.isRead
                                  ? null
                                  : AppColors.primary.withValues(alpha: 0.04),
                              title: Text(
                                _notificationText(item),
                                style: TextStyle(
                                  fontWeight: item.isRead
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(_timeLabel(item.createdAt)),
                              trailing: const Icon(
                                Icons.chevron_right,
                                size: 20,
                              ),
                              onTap: () => _openNotification(item),
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

  String _actorName(Map<String, dynamic> payload) {
    final actor = payload['actor_name'] as String?;
    return actor == null || actor.trim().isEmpty ? 'Un étudiant' : actor;
  }

  String _notificationText(AppNotification item) {
    final name = _actorName(item.payload);
    return switch (item.type) {
      'new_message' => '$name vous a envoyé un message.',
      'new_follower' => '$name a commencé à vous suivre.',
      'new_comment' => '$name a commenté votre publication.',
      'new_reaction' => '$name a réagi à votre publication.',
      'new_review' =>
        item.payload['rating'] == null
            ? '$name a laissé un avis sur votre vitrine.'
            : '$name a laissé un avis (${item.payload['rating']}/5).',
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
