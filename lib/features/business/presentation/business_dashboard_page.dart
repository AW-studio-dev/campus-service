import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_upload_validation.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_card.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/data/marketplace_repository.dart';
import '../../marketplace/presentation/marketplace_page.dart';

class BusinessDashboardPage extends ConsumerWidget {
  const BusinessDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    if (ownerId == null) {
      return const Center(
        child: Text('Connectez-vous pour gérer votre vitrine.'),
      );
    }

    final business = ref.watch(myBusinessProvider(ownerId));
    return business.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _DashboardMessage(
        message: 'Impossible de charger votre vitrine.',
        onRetry: () => ref.invalidate(myBusinessProvider(ownerId)),
      ),
      data: (record) {
        if (record == null) {
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
                    'Vous n’avez pas encore de vitrine',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/business/create'),
                    child: const Text('Créer mon business'),
                  ),
                ],
              ),
            ),
          );
        }
        final offers = ref.watch(manageBusinessListingsProvider(record.id));
        final reviews = ref.watch(businessReviewsProvider(record.id));
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mon business',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/business/${record.id}'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Voir la vitrine'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SocialCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    backgroundImage: record.logoUrl == null
                        ? null
                        : NetworkImage(record.logoUrl!),
                    child: record.logoUrl == null
                        ? const Icon(Icons.storefront_outlined)
                        : null,
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
                        Text(
                          _businessStatusLabel(record.status),
                          style: TextStyle(
                            color: record.status == 'published'
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Modifier les informations',
                    onPressed: () async {
                      final updated = await showDialog<bool>(
                        context: context,
                        builder: (context) => _BusinessDetailsDialog(
                          businessId: record.id,
                          initialName: record.name,
                          initialDescription: record.description,
                        ),
                      );
                      if (updated == true) {
                        ref.invalidate(myBusinessProvider(ownerId));
                        ref.invalidate(businessProvider(record.id));
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Personnaliser la vitrine',
                    onPressed: () async {
                      final updated = await showDialog<bool>(
                        context: context,
                        builder: (context) =>
                            _BusinessBrandingDialog(businessId: record.id),
                      );
                      if (updated == true) {
                        ref.invalidate(myBusinessProvider(ownerId));
                        ref.invalidate(businessProvider(record.id));
                      }
                    },
                    icon: const Icon(Icons.palette_outlined),
                  ),
                  IconButton(
                    tooltip: 'Ajouter une offre',
                    onPressed: () =>
                        _openOfferDialog(context, ref, businessId: record.id),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _BusinessVisibilityCard(
              status: record.status,
              onToggle: () => _toggleBusinessStatus(context, ref, record),
            ),
            const SizedBox(height: 16),
            _Statistics(
              offers: offers.asData?.value ?? const [],
              reviews: reviews.asData?.value ?? const [],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mes offres',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      _openOfferDialog(context, ref, businessId: record.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            offers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _DashboardMessage(
                message: 'Impossible de charger vos offres.',
                onRetry: () =>
                    ref.invalidate(manageBusinessListingsProvider(record.id)),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Ajoutez votre premier produit ou service.',
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth > 640 ? 3 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: columns == 2 ? 0.68 : 0.74,
                              ),
                          itemBuilder: (context, index) => _ManagedOfferCard(
                            businessId: record.id,
                            listing: items[index],
                            onEdit: () => _openOfferDialog(
                              context,
                              ref,
                              businessId: record.id,
                              listing: items[index],
                            ),
                            onToggle: () =>
                                _toggleOffer(context, ref, items[index]),
                            onDelete: () =>
                                _deleteOffer(context, ref, items[index]),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Avis reçus',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      ref.invalidate(businessReviewsProvider(record.id)),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualiser'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            reviews.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _DashboardMessage(
                message: 'Impossible de charger les avis.',
                onRetry: () =>
                    ref.invalidate(businessReviewsProvider(record.id)),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('Aucun avis pour le moment.')),
                    )
                  : Column(
                      children: [
                        for (final review in items) ...[
                          _ManagedReviewCard(
                            review: review,
                            onDelete: () => _deleteReview(context, ref, review),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openOfferDialog(
    BuildContext context,
    WidgetRef ref, {
    required String businessId,
    MarketplaceListing? listing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _OfferDialog(businessId: businessId, listing: listing),
    );
    if (saved == true) {
      ref.invalidate(manageBusinessListingsProvider(businessId));
      ref.invalidate(businessListingsProvider(businessId));
      ref.invalidate(marketplaceListingsProvider);
    }
  }

  Future<void> _toggleOffer(
    BuildContext context,
    WidgetRef ref,
    MarketplaceListing listing,
  ) async {
    final nextStatus = listing.status == 'available'
        ? 'unavailable'
        : 'available';
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .setOfferStatus(
            listingId: listing.id,
            isProduct: listing.isProduct,
            status: nextStatus,
          );
      ref.invalidate(manageBusinessListingsProvider(listing.businessId));
      ref.invalidate(businessListingsProvider(listing.businessId));
      ref.invalidate(marketplaceListingsProvider);
    } on Exception {
      if (context.mounted) {
        _showMessage(
          context,
          'Impossible de modifier la visibilité de cette offre.',
        );
      }
    }
  }

  Future<void> _deleteOffer(
    BuildContext context,
    WidgetRef ref,
    MarketplaceListing listing,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l’offre ?'),
        content: Text(
          '« ${listing.title} » sera définitivement retirée de votre vitrine.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .deleteOffer(listingId: listing.id, isProduct: listing.isProduct);
      ref.invalidate(manageBusinessListingsProvider(listing.businessId));
      ref.invalidate(businessListingsProvider(listing.businessId));
      ref.invalidate(marketplaceListingsProvider);
      if (context.mounted) _showMessage(context, 'Offre supprimée.');
    } on Exception {
      if (context.mounted) {
        _showMessage(context, 'Impossible de supprimer cette offre.');
      }
    }
  }

  Future<void> _deleteReview(
    BuildContext context,
    WidgetRef ref,
    BusinessReview review,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet avis ?'),
        content: Text(
          'L’avis de ${review.reviewerName} sera retiré de votre vitrine.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(marketplaceRepositoryProvider).deleteReview(review.id);
      ref.invalidate(businessReviewsProvider);
      if (context.mounted) _showMessage(context, 'Avis supprimé.');
    } on Exception {
      if (context.mounted) {
        _showMessage(context, 'Impossible de supprimer cet avis.');
      }
    }
  }

  Future<void> _toggleBusinessStatus(
    BuildContext context,
    WidgetRef ref,
    BusinessRecord record,
  ) async {
    if (record.status != 'published' && record.status != 'draft') {
      _showMessage(context, 'Cette vitrine est contrôlée par la modération.');
      return;
    }
    final nextStatus = record.status == 'published' ? 'draft' : 'published';
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .updateBusinessStatus(businessId: record.id, status: nextStatus);
      ref.invalidate(myBusinessProvider(record.ownerId));
      ref.invalidate(businessProvider(record.id));
      ref.invalidate(marketplaceListingsProvider);
      if (context.mounted) {
        _showMessage(
          context,
          nextStatus == 'published'
              ? 'Votre vitrine est publiée.'
              : 'Votre vitrine est en pause : elle n’apparaît plus dans le marketplace.',
        );
      }
    } on Exception {
      if (context.mounted) {
        _showMessage(context, 'Impossible de modifier la visibilité.');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String _businessStatusLabel(String status) {
  return switch (status) {
    'published' => 'Vitrine publiée',
    'suspended' => 'Vitrine suspendue par la modération',
    'archived' => 'Vitrine archivée',
    _ => 'Brouillon',
  };
}

String _offerStatusLabel(String status) {
  return switch (status) {
    'unavailable' => 'En pause',
    'reserved' => 'Réservée',
    'closed' => 'Fermée',
    'archived' => 'Archivée',
    _ => 'Publiée',
  };
}

Color _offerStatusColor(String status) {
  return switch (status) {
    'unavailable' => AppColors.warning,
    'closed' || 'archived' => AppColors.textSecondary,
    'reserved' => AppColors.info,
    _ => AppColors.success,
  };
}

class _BusinessVisibilityCard extends StatelessWidget {
  const _BusinessVisibilityCard({required this.status, required this.onToggle});

  final String status;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isPublished = status == 'published';
    final isModerated = status == 'suspended' || status == 'archived';
    return SocialCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            isPublished
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: isPublished ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPublished
                  ? 'Votre vitrine est visible dans le marketplace.'
                  : 'Votre vitrine est masquée du marketplace.',
            ),
          ),
          FilledButton.tonal(
            onPressed: isModerated ? null : onToggle,
            child: Text(isPublished ? 'Mettre en pause' : 'Publier'),
          ),
        ],
      ),
    );
  }
}

class _Statistics extends StatelessWidget {
  const _Statistics({required this.offers, required this.reviews});

  final List<MarketplaceListing> offers;
  final List<BusinessReview> reviews;

  @override
  Widget build(BuildContext context) {
    final published = offers
        .where((offer) => offer.status == 'available')
        .length;
    final paused = offers.length - published;
    final average = reviews.isEmpty
        ? null
        : reviews.fold<int>(0, (sum, review) => sum + review.rating) /
              reviews.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: columns == 4 ? 1.9 : 1.6,
          children: [
            _StatCard(
              icon: Icons.inventory_2_outlined,
              label: 'Offres publiées',
              value: '$published',
            ),
            _StatCard(
              icon: Icons.pause_circle_outline,
              label: 'Offres en pause',
              value: '$paused',
            ),
            _StatCard(
              icon: Icons.rate_review_outlined,
              label: 'Avis reçus',
              value: '${reviews.length}',
            ),
            _StatCard(
              icon: Icons.star_outline,
              label: 'Note moyenne',
              value: average == null ? '—' : average.toStringAsFixed(1),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SocialCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ManagedOfferCard extends StatelessWidget {
  const _ManagedOfferCard({
    required this.businessId,
    required this.listing,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final String businessId;
  final MarketplaceListing listing;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isAvailable = listing.status == 'available';
    return Stack(
      children: [
        MarketplaceListingCard(
          listing: listing,
          onTap: () => context.go(
            '/marketplace/item/${listing.id}'
            '?kind=${listing.isProduct ? 'product' : 'service'}',
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: AppColors.surface.withValues(alpha: 0.9),
            shape: const CircleBorder(),
            child: PopupMenuButton<String>(
              tooltip: 'Gérer l’offre',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                  case 'toggle':
                    onToggle();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier'),
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      isAvailable
                          ? Icons.pause_outlined
                          : Icons.play_arrow_outlined,
                    ),
                    title: Text(isAvailable ? 'Mettre en pause' : 'Republier'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isAvailable)
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _offerStatusColor(listing.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _offerStatusLabel(listing.status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ManagedReviewCard extends StatelessWidget {
  const _ManagedReviewCard({required this.review, required this.onDelete});

  final BusinessReview review;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SocialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.reviewerName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${review.rating}/5',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: 'Supprimer l’avis',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
          if (review.comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(review.comment),
            ),
          const SizedBox(height: 6),
          Text(
            '${review.createdAt.day.toString().padLeft(2, '0')}/'
            '${review.createdAt.month.toString().padLeft(2, '0')}/'
            '${review.createdAt.year}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OfferDialog extends ConsumerStatefulWidget {
  const _OfferDialog({required this.businessId, this.listing});

  final String businessId;
  final MarketplaceListing? listing;

  @override
  ConsumerState<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends ConsumerState<_OfferDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.listing?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.listing?.description ?? '',
  );
  late final _priceController = TextEditingController(
    text: widget.listing?.priceAmount == null
        ? ''
        : widget.listing!.priceAmount!.toStringAsFixed(2),
  );
  Uint8List? _imageBytes;
  late bool _isProduct = widget.listing?.isProduct ?? true;
  bool _isSubmitting = false;
  bool _isPicking = false;

  bool get _isEditing => widget.listing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _isPicking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!isValidImageUpload(bytes)) {
        _message('Choisissez une image JPEG ou PNG de 5 Mo maximum.');
        return;
      }
      if (mounted) setState(() => _imageBytes = bytes);
    } on Exception {
      _message('Impossible de lire cette image.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    final rawPrice = _priceController.text.trim().replaceAll(',', '.');
    final price = rawPrice.isEmpty ? null : double.tryParse(rawPrice);
    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(marketplaceRepositoryProvider);
      if (_isEditing) {
        await repository.updateOffer(
          listingId: widget.listing!.id,
          isProduct: widget.listing!.isProduct,
          businessId: widget.businessId,
          title: _titleController.text,
          description: _descriptionController.text,
          price: price,
          imageBytes: _imageBytes,
        );
      } else {
        await repository.addOffer(
          businessId: widget.businessId,
          title: _titleController.text,
          description: _descriptionController.text,
          price: price,
          isProduct: _isProduct,
          imageBytes: _imageBytes,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on StorageException catch (error) {
      debugPrint(
        'Business offer image upload failed '
        '(HTTP ${error.statusCode ?? 'unknown'}): ${error.error}',
      );
      _message(_businessStorageErrorMessage(error.statusCode));
    } on PostgrestException catch (error) {
      debugPrint(
        'Business offer save failed (code ${error.code ?? 'unknown'})',
      );
      _message(
        'Supabase n’a pas pu enregistrer cette offre '
        '(code ${error.code ?? 'inconnu'}).',
      );
    } on InvalidBusinessImageException {
      _message('L’image doit être JPEG ou PNG et faire 5 Mo maximum.');
    } on Exception {
      _message(
        _isEditing
            ? 'Impossible de modifier cette offre. Réessayez.'
            : 'Impossible d’ajouter cette offre. Réessayez.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Saisissez un titre.';
    if (title.length > 120) return '120 caractères maximum.';
    return null;
  }

  String? _validatePrice(String? value) {
    final text = value?.trim().replaceAll(',', '.') ?? '';
    if (text.isEmpty) return null;
    final price = double.tryParse(text);
    if (price == null || price < 0) return 'Saisissez un prix valide.';
    return null;
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Modifier l’offre' : 'Ajouter une offre'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isEditing) ...[
                  DropdownButtonFormField<bool>(
                    initialValue: _isProduct,
                    decoration: const InputDecoration(
                      labelText: 'Type d’offre',
                    ),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Produit')),
                      DropdownMenuItem(value: false, child: Text('Service')),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _isProduct = value ?? true),
                  ),
                  const SizedBox(height: 12),
                ] else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text(
                        widget.listing!.isProduct ? 'Produit' : 'Service',
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _titleController,
                  maxLength: 120,
                  validator: _validateTitle,
                  decoration: const InputDecoration(labelText: 'Titre'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Description (facultatif)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validatePrice,
                  decoration: const InputDecoration(
                    labelText: 'Prix en DZD (facultatif)',
                  ),
                ),
                if (_imageBytes != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _imageBytes!,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isPicking || _isSubmitting ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _imageBytes == null
                        ? (_isEditing
                              ? 'Remplacer l’image'
                              : 'Ajouter une image')
                        : 'Changer',
                  ),
                ),
                const Text(
                  'Une image JPEG ou PNG, 5 Mo maximum.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        PrimaryButton(
          label: _isEditing ? 'Mettre à jour' : 'Enregistrer',
          isLoading: _isSubmitting,
          expand: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _BusinessDetailsDialog extends ConsumerStatefulWidget {
  const _BusinessDetailsDialog({
    required this.businessId,
    required this.initialName,
    required this.initialDescription,
  });

  final String businessId;
  final String initialName;
  final String initialDescription;

  @override
  ConsumerState<_BusinessDetailsDialog> createState() =>
      _BusinessDetailsDialogState();
}

class _BusinessDetailsDialogState
    extends ConsumerState<_BusinessDetailsDialog> {
  late final _nameController = TextEditingController(text: widget.initialName);
  late final _descriptionController = TextEditingController(
    text: widget.initialDescription,
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _message('Le nom doit contenir au moins 2 caractères.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .updateBusinessDetails(
            businessId: widget.businessId,
            name: name,
            description: _descriptionController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception {
      _message('Impossible de mettre à jour la vitrine.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Informations de la vitrine'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              maxLength: 600,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        PrimaryButton(
          label: 'Enregistrer',
          isLoading: _isSaving,
          expand: false,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _BusinessBrandingDialog extends ConsumerStatefulWidget {
  const _BusinessBrandingDialog({required this.businessId});

  final String businessId;

  @override
  ConsumerState<_BusinessBrandingDialog> createState() =>
      _BusinessBrandingDialogState();
}

class _BusinessBrandingDialogState
    extends ConsumerState<_BusinessBrandingDialog> {
  Uint8List? _logoBytes;
  Uint8List? _coverBytes;
  bool _isPicking = false;
  bool _isSaving = false;

  Future<void> _pick(bool isLogo) async {
    setState(() => _isPicking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!isValidImageUpload(bytes)) {
        _message('Choisissez une image JPEG ou PNG de 5 Mo maximum.');
        return;
      }
      if (mounted) {
        setState(() {
          if (isLogo) {
            _logoBytes = bytes;
          } else {
            _coverBytes = bytes;
          }
        });
      }
    } on Exception {
      _message('Impossible de lire cette image.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _save() async {
    if (_logoBytes == null && _coverBytes == null) {
      _message('Choisissez au moins une image.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .updateBusinessBranding(
            businessId: widget.businessId,
            logoBytes: _logoBytes,
            coverBytes: _coverBytes,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on StorageException catch (error) {
      debugPrint(
        'Business branding image upload failed '
        '(HTTP ${error.statusCode ?? 'unknown'}): ${error.error}',
      );
      _message(_businessStorageErrorMessage(error.statusCode));
    } on PostgrestException catch (error) {
      debugPrint(
        'Business branding update failed (code ${error.code ?? 'unknown'})',
      );
      _message(
        'Supabase n’a pas pu mettre à jour la vitrine '
        '(code ${error.code ?? 'inconnu'}). Vérifiez les droits du business.',
      );
    } on InvalidBusinessImageException {
      _message('Les images doivent être JPEG ou PNG et faire 5 Mo maximum.');
    } on Exception {
      _message('Impossible de mettre à jour la vitrine. Réessayez.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Personnaliser ma vitrine'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_coverBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _coverBytes!,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
            OutlinedButton.icon(
              onPressed: _isPicking || _isSaving ? null : () => _pick(false),
              icon: const Icon(Icons.photo_outlined),
              label: Text(
                _coverBytes == null
                    ? 'Choisir une bannière'
                    : 'Changer la bannière',
              ),
            ),
            const SizedBox(height: 8),
            if (_logoBytes != null)
              Center(
                child: ClipOval(
                  child: Image.memory(
                    _logoBytes!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _isPicking || _isSaving ? null : () => _pick(true),
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(
                _logoBytes == null ? 'Choisir un logo' : 'Changer le logo',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Images JPEG/PNG uniquement, 5 Mo maximum chacune.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        PrimaryButton(
          label: 'Enregistrer',
          isLoading: _isSaving,
          expand: false,
          onPressed: _isPicking ? null : _save,
        ),
      ],
    );
  }
}

String _businessStorageErrorMessage(String? statusCode) {
  return switch (statusCode) {
    '401' || '403' =>
      'Supabase refuse l’envoi. Vérifiez les règles d’accès au stockage '
          'business-media.',
    '404' =>
      'Le stockage business-media est introuvable. Appliquez les migrations '
          'Supabase.',
    '413' => 'L’image dépasse la limite autorisée par le stockage.',
    '400' =>
      'Supabase refuse le format de cette image. Utilisez un JPG ou PNG.',
    _ =>
      'Échec de l’envoi vers Supabase (HTTP ${statusCode ?? 'inconnu'}). '
          'Vérifiez la connexion et le stockage.',
  };
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({required this.message, this.onRetry});

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
