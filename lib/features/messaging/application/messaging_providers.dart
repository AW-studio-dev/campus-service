import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/messaging_repository.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => MessagingRepository(ref.watch(supabaseClientProvider)),
);

final inboxProvider = FutureProvider<List<InboxConversation>>((ref) {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) {
    throw StateError('Une session est nécessaire pour voir la messagerie.');
  }
  return ref.watch(messagingRepositoryProvider).fetchInbox(userId);
});

final conversationMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, conversationId) {
      return ref
          .watch(messagingRepositoryProvider)
          .fetchMessages(conversationId);
    });

final conversationTitleProvider = FutureProvider.family<String?, String>((
  ref,
  conversationId,
) {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return null;
  return ref
      .watch(messagingRepositoryProvider)
      .fetchOtherMemberName(
        conversationId: conversationId,
        currentUserId: userId,
      );
});
