import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/marketplace_repository.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>(
  (ref) => MarketplaceRepository(ref.watch(supabaseClientProvider)),
);

final marketplaceCategoriesProvider = FutureProvider<List<MarketplaceCategory>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).loadCategories(),
);

final marketplaceListingsProvider =
    FutureProvider.family<List<MarketplaceListing>, MarketplaceFilter>((
      ref,
      filter,
    ) {
      return ref
          .watch(marketplaceRepositoryProvider)
          .loadListings(categoryId: filter.categoryId, kind: filter.kind);
    });

final businessLookupsProvider = FutureProvider<BusinessLookups>(
  (ref) => ref.watch(marketplaceRepositoryProvider).loadBusinessLookups(),
);

final businessProvider = FutureProvider.family<BusinessRecord?, String>((
  ref,
  businessId,
) {
  return ref.watch(marketplaceRepositoryProvider).fetchBusiness(businessId);
});

final myBusinessProvider = FutureProvider.family<BusinessRecord?, String>((
  ref,
  userId,
) {
  return ref.watch(marketplaceRepositoryProvider).fetchMyBusiness(userId);
});

final businessListingsProvider =
    FutureProvider.family<List<MarketplaceListing>, String>((ref, businessId) {
      return ref
          .watch(marketplaceRepositoryProvider)
          .fetchBusinessListings(businessId);
    });

/// Toutes les offres du propriétaire, y compris celles mises en pause.
final manageBusinessListingsProvider =
    FutureProvider.family<List<MarketplaceListing>, String>((ref, businessId) {
      return ref
          .watch(marketplaceRepositoryProvider)
          .fetchBusinessListings(businessId, includeHidden: true);
    });

final businessReviewsProvider =
    FutureProvider.family<List<BusinessReview>, String>((ref, businessId) {
      return ref
          .watch(marketplaceRepositoryProvider)
          .fetchBusinessReviews(businessId);
    });

final marketplaceListingProvider =
    FutureProvider.family<MarketplaceListing?, MarketplaceListingKey>((
      ref,
      key,
    ) {
      return ref
          .watch(marketplaceRepositoryProvider)
          .fetchListing(listingId: key.id, isProduct: key.isProduct);
    });

class MarketplaceFilter {
  const MarketplaceFilter({required this.categoryId, required this.kind});

  final int? categoryId;
  final String kind;

  @override
  bool operator ==(Object other) =>
      other is MarketplaceFilter &&
      other.categoryId == categoryId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(categoryId, kind);
}

class MarketplaceListingKey {
  const MarketplaceListingKey({required this.id, required this.isProduct});

  final String id;
  final bool isProduct;

  @override
  bool operator ==(Object other) =>
      other is MarketplaceListingKey &&
      other.id == id &&
      other.isProduct == isProduct;

  @override
  int get hashCode => Object.hash(id, isProduct);
}
