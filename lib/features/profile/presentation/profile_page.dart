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
import '../../requests/application/service_request_providers.dart';
import '../../requests/data/service_request_repository.dart';
import '../application/profile_providers.dart';
import '../data/profile_repository.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({this.profileId, this.initialTab, super.key});

  final String? profileId;
  final String? initialTab;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isFollowingBusy = false;
  bool _isBlockBusy = false;

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

  Future<void> _toggleBlock(ProfileRecord profile, String viewerId) async {
    if (_isBlockBusy) return;
    setState(() => _isBlockBusy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .setBlocked(
            blockerId: viewerId,
            blockedId: profile.id,
            isBlocked: !profile.isBlockedByViewer,
          );
      if (!mounted) return;
      ref.invalidate(profileProvider(profile.id));
      ref.invalidate(feedPostsProvider);
      _showMessage(
        profile.isBlockedByViewer
            ? 'Utilisateur débloqué.'
            : 'Utilisateur bloqué. Ses publications sont masquées.',
      );
    } on Exception {
      _showMessage('Impossible de modifier le blocage.');
    } finally {
      if (mounted) setState(() => _isBlockBusy = false);
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
        final tabCount = isOwner ? 4 : 2;
        final initialIndex = isOwner
            ? switch (widget.initialTab) {
                'requests' => 2,
                'saved' => 3,
                _ => 0,
              }
            : 0;
        return DefaultTabController(
          length: tabCount,
          initialIndex: initialIndex,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: _ProfileHeader(
                  profile: record,
                  isOwner: isOwner,
                  isFollowingBusy: _isFollowingBusy,
                  isBlockBusy: _isBlockBusy,
                  onEdit: () => context.go('/profile/edit'),
                  onFollow: isOwner || viewerId == null
                      ? null
                      : () => _toggleFollow(record, viewerId),
                  onBlock: isOwner || viewerId == null
                      ? null
                      : () => _toggleBlock(record, viewerId),
                  onMessage: isOwner
                      ? null
                      : () => context.go(
                          '/chat/new?userId=${Uri.encodeComponent(record.id)}',
                        ),
                  onBusiness: isOwner
                      ? () => context.go('/business/manage')
                      : null,
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _ProfileTabBarDelegate(
                  TabBar(
                    tabs: [
                      const Tab(text: 'Publications'),
                      const Tab(text: 'À propos'),
                      if (isOwner) const Tab(text: 'Mes demandes'),
                      if (isOwner) const Tab(text: 'Favoris'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _PostList(profileId: record.id, posts: posts, saved: false),
                _AboutProfile(profile: record),
                if (isOwner) _RequestsList(authorId: record.id),
                if (isOwner)
                  _SavedPostList(posts: ref.watch(savedPostsProvider)),
              ],
            ),
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

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.isOwner,
    required this.isFollowingBusy,
    required this.isBlockBusy,
    this.onEdit,
    this.onFollow,
    this.onBlock,
    this.onMessage,
    this.onBusiness,
  });

  final ProfileRecord profile;
  final bool isOwner;
  final bool isFollowingBusy;
  final bool isBlockBusy;
  final VoidCallback? onEdit;
  final VoidCallback? onFollow;
  final VoidCallback? onBlock;
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
                                  profile.isFollowing ? 'Abonné' : 'S\'abonner',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: onMessage,
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Message'),
                              ),
                              OutlinedButton.icon(
                                onPressed: isBlockBusy ? null : onBlock,
                                icon: Icon(
                                  profile.isBlockedByViewer
                                      ? Icons.lock_open_outlined
                                      : Icons.block,
                                ),
                                label: Text(
                                  profile.isBlockedByViewer
                                      ? 'Débloquer'
                                      : 'Bloquer',
                                ),
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

class _RequestsList extends ConsumerWidget {
  const _RequestsList({required this.authorId});

  final String authorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myServiceRequestsProvider(authorId));
    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ProfileMessage(
        message: 'Impossible de charger vos demandes.',
        onRetry: () => ref.invalidate(myServiceRequestsProvider(authorId)),
      ),
      data: (items) => items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Vous n’avez publié aucune demande.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => GoRouter.of(context).go('/help-request'),
                    icon: const Icon(Icons.add),
                    label: const Text('Demander de l’aide'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _RequestCard(request: items[index]),
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final ServiceRequestSummary request;

  @override
  Widget build(BuildContext context) {
    final details = [
      _requestTypeLabel(request.type),
      _requestFormatLabel(request.format),
      if (request.subject != null) request.subject!,
      if (request.level != null) request.level!,
      if (request.wilaya != null) request.wilaya!,
    ];
    return SocialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(
                label: _requestStatusLabel(request.status),
                color: _requestStatusColor(request.status),
              ),
            ],
          ),
          if (request.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final detail in details)
                Chip(
                  label: Text(detail, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Publiée le ${_shortDate(request.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (request.budgetAmount != null)
                Text(
                  '${request.budgetAmount!.toStringAsFixed(0)} DZD',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _requestTypeLabel(String type) => switch (type) {
    'private_tutoring' => 'Cours particulier',
    'partner_search' => 'Recherche de partenaire',
    'project_team' => 'Équipe de projet',
    'freelance_search' => 'Mission freelance',
    'other' => 'Autre',
    _ => 'Aide académique',
  };

  String _requestFormatLabel(String format) => switch (format) {
    'in_person' => 'Présentiel',
    'hybrid' => 'Hybride',
    _ => 'En ligne',
  };

  String _requestStatusLabel(String status) => switch (status) {
    'in_discussion' => 'En discussion',
    'fulfilled' => 'Satisfaite',
    'closed' => 'Fermée',
    'expired' => 'Expirée',
    _ => 'Ouverte',
  };

  Color _requestStatusColor(String status) => switch (status) {
    'fulfilled' => AppColors.success,
    'closed' || 'expired' => AppColors.textSecondary,
    'in_discussion' => AppColors.secondary,
    _ => AppColors.primary,
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
