import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../ads/presentation/sponsored_banner.dart';
import '../../ads/presentation/sponsored_post_card.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/presentation/marketplace_page.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/post_card.dart';
import '../../../shared/widgets/social_card.dart';
import '../application/post_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(feedPostsProvider);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Fil d’actualité',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: () => ref.invalidate(feedPostsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SocialCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AppAvatar(name: user?.userMetadata?['display_name'] as String?),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: AppColors.textSecondary,
                    ),
                    onPressed: () => context.go('/create-post'),
                    child: const Text('Quoi de neuf sur votre campus ?'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Ajouter une photo',
                  onPressed: () => context.go('/create-post'),
                  icon: const Icon(Icons.image_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SponsoredBanner(),
        const SizedBox(height: 12),
        Expanded(
          child: posts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                _FeedError(onRetry: () => ref.invalidate(feedPostsProvider)),
            data: (items) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(feedPostsProvider);
                ref.invalidate(marketplaceListingsProvider);
                await ref.read(feedPostsProvider.future);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: items.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _HomeServicesSection(),
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Publications',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                        ] else
                          _EmptyFeed(
                            onCreatePost: () => context.go('/create-post'),
                            onRequestHelp: () => context.go('/help-request'),
                          ),
                      ],
                    );
                  }
                  final post = items[index - 1];
                  final card = PostCard(
                    post: post,
                    onLike: () async {
                      final userId = ref
                          .read(supabaseClientProvider)
                          .auth
                          .currentUser
                          ?.id;
                      if (userId == null) {
                        if (context.mounted) {
                          _showMessage(
                            context,
                            'Votre session a expiré. Reconnectez-vous.',
                          );
                        }
                        return;
                      }
                      try {
                        await ref
                            .read(postRepositoryProvider)
                            .toggleLike(postId: post.id, userId: userId);
                        if (!context.mounted) return;
                        ref.invalidate(feedPostsProvider);
                      } on Exception {
                        if (context.mounted) {
                          _showMessage(
                            context,
                            'Impossible d’enregistrer votre réaction.',
                          );
                        }
                      }
                    },
                    onSave: () async {
                      final userId = ref
                          .read(supabaseClientProvider)
                          .auth
                          .currentUser
                          ?.id;
                      if (userId == null) {
                        if (context.mounted) {
                          _showMessage(
                            context,
                            'Votre session a expiré. Reconnectez-vous.',
                          );
                        }
                        return;
                      }
                      try {
                        await ref
                            .read(postRepositoryProvider)
                            .toggleSavedPost(postId: post.id, userId: userId);
                        if (!context.mounted) return;
                        ref.invalidate(feedPostsProvider);
                        ref.invalidate(savedPostsProvider);
                      } on Exception {
                        if (context.mounted) {
                          _showMessage(
                            context,
                            'Impossible de modifier vos favoris.',
                          );
                        }
                      }
                    },
                    onCommentsChanged: () => ref.invalidate(feedPostsProvider),
                  );
                  return post.isSponsored
                      ? SponsoredPostCard(post: post, child: card)
                      : card;
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HomeServicesSection extends ConsumerWidget {
  const _HomeServicesSection();

  static const _filter = MarketplaceFilter(categoryId: null, kind: 'all');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(marketplaceListingsProvider(_filter));
    return listings.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Services & offres',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/marketplace'),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 232,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final listing = items[index];
                  return SizedBox(
                    width: 168,
                    child: MarketplaceListingCard(
                      listing: listing,
                      onTap: () => context.go(
                        '/marketplace/item/${listing.id}'
                        '?kind=${listing.isProduct ? 'product' : 'service'}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onCreatePost, required this.onRequestHelp});

  final VoidCallback onCreatePost;
  final VoidCallback onRequestHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.dynamic_feed_outlined,
              size: 52,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Votre fil commence ici',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Aucune publication pour le moment. Partagez une nouvelle '
              'avec la communauté ou demandez un coup de main.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onCreatePost,
                  icon: const Icon(Icons.add),
                  label: const Text('Créer une publication'),
                ),
                OutlinedButton.icon(
                  onPressed: onRequestHelp,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Demander de l’aide'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Impossible de charger le fil. Vérifiez votre connexion et '
              'réessayez.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
