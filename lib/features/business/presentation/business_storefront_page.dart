import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_card.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/data/marketplace_repository.dart';
import '../../marketplace/presentation/marketplace_page.dart';

class BusinessStorefrontPage extends ConsumerStatefulWidget {
  const BusinessStorefrontPage({required this.businessId, super.key});

  final String businessId;

  @override
  ConsumerState<BusinessStorefrontPage> createState() =>
      _BusinessStorefrontPageState();
}

class _BusinessStorefrontPageState
    extends ConsumerState<BusinessStorefrontPage> {
  String _kind = 'all';

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(businessProvider(widget.businessId));
    final offers = ref.watch(businessListingsProvider(widget.businessId));
    final currentUserId = ref
        .watch(supabaseClientProvider)
        .auth
        .currentUser
        ?.id;

    return business.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _StorefrontMessage(
        message: 'Impossible de charger cette vitrine.',
        onRetry: () => ref.invalidate(businessProvider(widget.businessId)),
      ),
      data: (record) {
        if (record == null) {
          return const Center(child: Text('Cette vitrine est introuvable.'));
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
                Expanded(
                  child: Text(
                    record.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (record.ownerId == currentUserId)
                  IconButton(
                    tooltip: 'Gérer ma vitrine',
                    onPressed: () => context.go('/business/manage'),
                    icon: const Icon(Icons.settings_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SocialCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 170,
                    child: record.coverUrl == null
                        ? Container(
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              size: 52,
                              color: Colors.white,
                            ),
                          )
                        : ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: Image.network(
                              record.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const ColoredBox(
                                    color: AppColors.primary,
                                    child: Icon(
                                      Icons.storefront_outlined,
                                      color: Colors.white,
                                      size: 52,
                                    ),
                                  ),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppAvatar(
                          imageUrl: record.logoUrl,
                          name: record.name,
                          size: 58,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.description.isEmpty
                                    ? 'Business étudiant'
                                    : record.description,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
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
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: [
                for (final (kind, label) in [
                  ('all', 'Tout'),
                  ('product', 'Produits'),
                  ('service', 'Services'),
                  ('reviews', 'Avis'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_kind == 'reviews')
              _buildReviews(context, record, currentUserId)
            else
              offers.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => _StorefrontMessage(
                  message: 'Impossible de charger les offres.',
                  onRetry: () => ref.invalidate(
                    businessListingsProvider(widget.businessId),
                  ),
                ),
                data: (items) {
                  final visible = _kind == 'all'
                      ? items
                      : items
                            .where(
                              (item) => item.isProduct == (_kind == 'product'),
                            )
                            .toList();
                  if (visible.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Aucune offre publiée pour le moment.'),
                      ),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth > 640 ? 3 : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visible.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: columns == 2 ? 0.72 : 0.78,
                        ),
                        itemBuilder: (context, index) => MarketplaceListingCard(
                          listing: visible[index],
                          onTap: () => context.go(
                            '/marketplace/item/${visible[index].id}'
                            '?kind=${visible[index].isProduct ? 'product' : 'service'}',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildReviews(
    BuildContext context,
    BusinessRecord business,
    String? currentUserId,
  ) {
    final reviews = ref.watch(businessReviewsProvider(business.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currentUserId != null && currentUserId != business.ownerId)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async {
                final submitted = await showDialog<bool>(
                  context: context,
                  builder: (context) => _ReviewDialog(businessId: business.id),
                );
                if (submitted == true) {
                  ref.invalidate(businessReviewsProvider(business.id));
                }
              },
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Laisser un avis'),
            ),
          ),
        const SizedBox(height: 8),
        reviews.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _StorefrontMessage(
            message: 'Impossible de charger les avis.',
            onRetry: () => ref.invalidate(businessReviewsProvider(business.id)),
          ),
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Aucun avis pour le moment.')),
                )
              : Column(
                  children: [
                    for (final review in items) ...[
                      SocialCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    review.reviewerName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  '${review.rating}/5',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              review.comment.isEmpty
                                  ? 'Aucun commentaire.'
                                  : review.comment,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _StorefrontMessage extends StatelessWidget {
  const _StorefrontMessage({required this.message, this.onRetry});

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

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.businessId});

  final String businessId;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .submitReview(
            reviewerId: userId,
            businessId: widget.businessId,
            rating: _rating,
            comment: _commentController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Impossible de publier cet avis.')),
          );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Votre avis'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _rating,
              decoration: const InputDecoration(labelText: 'Note'),
              items: [
                for (var rating = 5; rating >= 1; rating--)
                  DropdownMenuItem(
                    value: rating,
                    child: Text(
                      '$rating / 5 ${List.filled(rating, '★').join()}',
                    ),
                  ),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _rating = value ?? 5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Commentaire (facultatif)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        PrimaryButton(
          label: 'Publier',
          isLoading: _isSubmitting,
          expand: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
