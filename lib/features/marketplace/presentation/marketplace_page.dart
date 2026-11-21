import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/social_card.dart';
import '../application/marketplace_providers.dart';
import '../data/marketplace_repository.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  String _kind = 'all';
  int? _categoryId;

  @override
  Widget build(BuildContext context) {
    final filter = MarketplaceFilter(categoryId: _categoryId, kind: _kind);
    final listings = ref.watch(marketplaceListingsProvider(filter));
    final categories = ref.watch(marketplaceCategoriesProvider);
    final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Marketplace',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Mon business',
                onPressed: () => context.go('/business/manage'),
                icon: const Icon(Icons.storefront_outlined),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: () =>
                    ref.invalidate(marketplaceListingsProvider(filter)),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'Tout',
                selected: _kind == 'all',
                onTap: () => setState(() => _kind = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Produits',
                selected: _kind == 'product',
                onTap: () => setState(() => _kind = 'product'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Services',
                selected: _kind == 'service',
                onTap: () => setState(() => _kind = 'service'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: categories.when(
            loading: () => const Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, stackTrace) => Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => ref.invalidate(marketplaceCategoriesProvider),
                child: const Text('Recharger les catégories'),
              ),
            ),
            data: (items) => ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Toutes catégories',
                  selected: _categoryId == null,
                  onTap: () => setState(() => _categoryId = null),
                ),
                for (final category in items) ...[
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: category.name,
                    selected: _categoryId == category.id,
                    onTap: () => setState(() => _categoryId = category.id),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: listings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _MarketplaceError(
              onRetry: () =>
                  ref.invalidate(marketplaceListingsProvider(filter)),
            ),
            data: (items) => items.isEmpty
                ? _EmptyMarketplace(
                    isOwnerSignedIn: userId != null,
                    onCreateBusiness: () => context.go('/business/create'),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 640 ? 3 : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: columns == 2 ? 0.72 : 0.78,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => MarketplaceListingCard(
                          listing: items[index],
                          onTap: () => context.go(
                            '/marketplace/item/${items[index].id}'
                            '?kind=${items[index].isProduct ? 'product' : 'service'}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class MarketplaceListingCard extends StatelessWidget {
  const MarketplaceListingCard({
    required this.listing,
    required this.onTap,
    super.key,
  });

  final MarketplaceListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SocialCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: listing.imageUrl == null
                    ? Container(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        child: Icon(
                          listing.isProduct
                              ? Icons.shopping_bag_outlined
                              : Icons.handyman_outlined,
                          size: 44,
                          color: AppColors.secondary,
                        ),
                      )
                    : Image.network(
                        listing.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image_outlined, size: 40),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.priceAmount == null
                        ? 'Prix à convenir'
                        : '${listing.priceAmount!.toStringAsFixed(0)} '
                              '${listing.currency}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _EmptyMarketplace extends StatelessWidget {
  const _EmptyMarketplace({
    required this.isOwnerSignedIn,
    required this.onCreateBusiness,
  });

  final bool isOwnerSignedIn;
  final VoidCallback onCreateBusiness;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 48,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune offre pour le moment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Les produits et services publiés par les businesses étudiants '
              'apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (isOwnerSignedIn) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onCreateBusiness,
                child: const Text('Créer mon business'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketplaceError extends StatelessWidget {
  const _MarketplaceError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Impossible de charger le marketplace.'),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
