import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/post_repository.dart';

final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepository(ref.watch(supabaseClientProvider)),
);

final feedPostsProvider = FutureProvider<List<FeedPost>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw StateError('Une session est nécessaire pour consulter le fil.');
  }
  return ref
      .watch(postRepositoryProvider)
      .fetchFeed(currentUserId: userId, personalized: true);
});

final userPostsProvider = FutureProvider.family<List<FeedPost>, String>((
  ref,
  authorId,
) {
  final client = ref.watch(supabaseClientProvider);
  final currentUserId = client.auth.currentUser?.id;
  if (currentUserId == null) {
    throw StateError('Une session est nécessaire pour consulter les posts.');
  }
  return ref
      .watch(postRepositoryProvider)
      .fetchFeed(currentUserId: currentUserId, authorId: authorId);
});

final savedPostsProvider = FutureProvider<List<FeedPost>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final currentUserId = client.auth.currentUser?.id;
  if (currentUserId == null) {
    throw StateError('Une session est nécessaire pour consulter les favoris.');
  }
  final savedItems = await client
      .from('saved_items')
      .select('item_id')
      .eq('user_id', currentUserId)
      .eq('item_type', 'post')
      .order('created_at', ascending: false)
      .limit(50);
  final postIds = savedItems.map((item) => item['item_id'] as String).toList();
  return ref
      .watch(postRepositoryProvider)
      .fetchFeed(currentUserId: currentUserId, onlyPostIds: postIds);
});

final postCommentsProvider = FutureProvider.family<List<PostComment>, String>((
  ref,
  postId,
) {
  return ref.watch(postRepositoryProvider).fetchComments(postId);
});
