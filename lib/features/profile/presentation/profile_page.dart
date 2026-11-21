import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/feed/data/post_repository.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/post_card.dart';
import '../../../shared/widgets/social_card.dart';
import '../../feed/application/post_providers.dart';
import '../application/profile_providers.dart';
import '../data/profile_repository.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({this.profileId, super.key});

  final String? profileId;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isFollowingBusy = false;

  Future<void> _toggleFollow(ProfileRecord profile, String viewerId) async {
    if (_isFollowingBusy) return;
    setState(() => _isFollowingBusy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .toggleFollow(followerId: viewerId, followingId: profile.id);
      if (!mounted) return;
      ref.invalidate(profileProvider(profile.id));
    } on Exception {
      _showMessage('Impossible de modifier l’abonnement.');
    } finally {
      if (mounted) setState(() => _isFollowingBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewerId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final profileId = widget.profileId ?? viewerId;
    if (profileId == null) {
      return const Center(
        child: Text('Connectez-vous pour voir votre profil.'),
      );
    }
    final profile = ref.watch(profileProvider(profileId));
    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ProfileMessage(
        message: 'Impossible de charger le profil.',
        onRetry: () => ref.invalidate(profileProvider(profileId)),
      ),
      data: (record) {
        if (record == null) {
          return const Center(child: Text('Utilisateur introuvable.'));
        }
        final isOwner = record.id == viewerId;
        final posts = ref.watch(userPostsProvider(record.id));
        return DefaultTabController(
          length: isOwner ? 3 : 2,
          child: Column(
            children: [
              _ProfileHeader(
                profile: record,
                isOwner: isOwner,
                isFollowingBusy: _isFollowingBusy,
                onEdit: () => context.go('/profile/edit'),
                onFollow: isOwner || viewerId == null
                    ? null
                    : () => _toggleFollow(record, viewerId),
                onMessage: isOwner
                    ? null
                    : () => context.go(
                        '/chat/new?userId=${Uri.encodeComponent(record.id)}',
                      ),
                onBusiness: isOwner
                    ? () => context.go('/business/manage')
                    : null,
              ),
              Material(
                color: AppColors.surface,
                child: TabBar(
                  tabs: [
                    const Tab(text: 'Publications'),
                    const Tab(text: 'À propos'),
                    if (isOwner) const Tab(text: 'Favoris'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _PostList(profileId: record.id, posts: posts, saved: false),
                    _AboutProfile(profile: record),
                    if (isOwner)
                      _SavedPostList(posts: ref.watch(savedPostsProvider)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.isOwner,
    required this.isFollowingBusy,
    this.onEdit,
    this.onFollow,
    this.onMessage,
    this.onBusiness,
  });

  final ProfileRecord profile;
  final bool isOwner;
  final bool isFollowingBusy;
  final VoidCallback? onEdit;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;
  final VoidCallback? onBusiness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SocialCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              height: 110,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -34),
                    child: AppAvatar(
                      imageUrl: profile.avatarUrl,
                      name: profile.displayName,
                      size: 72,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (profile.university != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              profile.university!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        if (profile.bio.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(profile.bio),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 18,
                          runSpacing: 8,
                          children: [
                            _ProfileStat(
                              value: profile.postsCount,
                              label: 'publications',
                            ),
                            _ProfileStat(
                              value: profile.followersCount,
                              label: 'abonnés',
                            ),
                            _ProfileStat(
                              value: profile.followingCount,
                              label: 'abonnements',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isOwner) ...[
                              OutlinedButton.icon(
                                onPressed: onEdit,
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Modifier le profil'),
                              ),
                              OutlinedButton.icon(
                                onPressed: onBusiness,
                                icon: const Icon(Icons.storefront_outlined),
                                label: const Text('Mon business'),
                              ),
                            ] else ...[
                              FilledButton.icon(
                                onPressed: isFollowingBusy ? null : onFollow,
                                icon: Icon(
                                  profile.isFollowing
                                      ? Icons.person_remove_outlined
                                      : Icons.person_add_alt_1_outlined,
                                ),
                                label: Text(
                                  profile.isFollowing
                                      ? 'Abonné'
                                      : 'S\'abonner',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: onMessage,
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Message'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          TextSpan(
            text: '$value ',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: label),
        ],
      ),
    );
  }
}

class _AboutProfile extends StatelessWidget {
  const _AboutProfile({required this.profile});

  final ProfileRecord profile;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (profile.university != null) ('Université', profile.university!),
      if (profile.wilaya != null) ('Wilaya', profile.wilaya!),
      if (profile.studyLevel != null) ('Niveau d’études', profile.studyLevel!),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SocialCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('À propos', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                profile.bio.isEmpty
                    ? 'Aucune biographie renseignée.'
                    : profile.bio,
              ),
              for (final (label, value) in details) ...[
                const Divider(height: 24),
                Text(
                  label,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 3),
                Text(value),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PostList extends ConsumerWidget {
  const _PostList({
    required this.profileId,
    required this.posts,
    required this.saved,
  });

  final String profileId;
  final AsyncValue<List<FeedPost>> posts;
  final bool saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return posts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ProfileMessage(
        message: 'Impossible de charger les publications.',
        onRetry: () => ref.invalidate(userPostsProvider(profileId)),
      ),
      data: (items) => items.isEmpty
          ? const Center(child: Text('Aucune publication pour le moment.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _ProfilePostCard(post: items[index], savedList: saved),
            ),
    );
  }
}

class _SavedPostList extends ConsumerWidget {
  const _SavedPostList({required this.posts});

  final AsyncValue<List<FeedPost>> posts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return posts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ProfileMessage(
        message: 'Impossible de charger les publications enregistrées.',
        onRetry: () => ref.invalidate(savedPostsProvider),
      ),
      data: (items) => items.isEmpty
          ? const Center(child: Text('Aucune publication enregistrée.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _ProfilePostCard(post: items[index], savedList: true),
            ),
    );
  }
}

class _ProfilePostCard extends ConsumerWidget {
  const _ProfilePostCard({required this.post, required this.savedList});

  final FeedPost post;
  final bool savedList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(postRepositoryProvider);
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    return PostCard(
      post: post,
      onLike: () async {
        if (userId == null) return;
        try {
          await repo.toggleLike(postId: post.id, userId: userId);
          if (!context.mounted) return;
          ref.invalidate(userPostsProvider(post.authorId));
          ref.invalidate(savedPostsProvider);
        } on Exception {
          if (context.mounted) _showMessage(context, 'Réaction impossible.');
        }
      },
      onSave: () async {
        if (userId == null) return;
        try {
          await repo.toggleSavedPost(postId: post.id, userId: userId);
          if (!context.mounted) return;
          if (savedList) {
            ref.invalidate(savedPostsProvider);
          } else {
            ref.invalidate(userPostsProvider(post.authorId));
            ref.invalidate(savedPostsProvider);
          }
        } on Exception {
          if (context.mounted) {
            _showMessage(context, 'Impossible de modifier les favoris.');
          }
        }
      },
      onCommentsChanged: () {
        ref.invalidate(userPostsProvider(post.authorId));
        ref.invalidate(savedPostsProvider);
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
