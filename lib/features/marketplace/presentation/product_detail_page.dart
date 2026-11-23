import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_card.dart';
import '../../messaging/application/messaging_providers.dart';
import '../application/marketplace_providers.dart';
import '../../../core/providers/supabase_provider.dart';

class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({
    required this.listingId,
    required this.isProduct,
    super.key,
  });

  final String listingId;
  final bool isProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = MarketplaceListingKey(id: listingId, isProduct: isProduct);
    final listing = ref.watch(marketplaceListingProvider(key));
    final currentUserId = ref
        .watch(supabaseClientProvider)
        .auth
        .currentUser
        ?.id;
    return listing.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _DetailMessage(
        message: 'Impossible de charger cette offre.',
        onRetry: () => ref.invalidate(marketplaceListingProvider(key)),
      ),
      data: (item) {
        if (item == null) {
          return const Center(child: Text('Cette offre est introuvable.'));
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Retour au marketplace',
                  onPressed: () => context.go('/marketplace'),
                  icon: const Icon(Icons.arrow_back),
                ),
                Text(
                  item.isProduct ? 'Produit' : 'Service',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SocialCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (item.imageUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: Image.network(
                        item.imageUrl!,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                              height: 220,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                      ),
                    )
                  else
                    Container(
                      height: 220,
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: Icon(
                        item.isProduct
                            ? Icons.shopping_bag_outlined
                            : Icons.handyman_outlined,
                        size: 56,
                        color: AppColors.secondary,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.priceAmount == null
                              ? 'Prix à convenir'
                              : '${item.priceAmount!.toStringAsFixed(0)} '
                                    '${item.currency}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.description.isEmpty
                              ? 'Aucune description supplémentaire.'
                              : item.description,
                          style: const TextStyle(height: 1.5),
                        ),
                        const Divider(height: 28),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () =>
                              context.go('/profile/${item.businessOwnerId}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                AppAvatar(name: item.businessName, size: 42),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Vendu par',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        item.businessName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        PrimaryButton(
                          label: 'Contacter le vendeur',
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          onPressed:
                              currentUserId == null ||
                                  currentUserId == item.businessOwnerId
                              ? null
                              : () async {
                                  try {
                                    final conversationId = await ref
                                        .read(messagingRepositoryProvider)
                                        .startDirectConversation(
                                          currentUserId: currentUserId,
                                          otherUserId: item.businessOwnerId,
                                          listingId: item.id,
                                          listingTitle: item.title,
                                          listingType: item.isProduct
                                              ? 'product'
                                              : 'service',
                                        );
                                    if (context.mounted) {
                                      context.go('/chat/$conversationId');
                                    }
                                  } on Exception {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Impossible de contacter ce vendeur.',
                                            ),
                                          ),
                                        );
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.message, this.onRetry});

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
