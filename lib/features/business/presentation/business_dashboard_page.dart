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
        final offers = ref.watch(businessListingsProvider(record.id));
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
                          record.status == 'published'
                              ? 'Vitrine publiée'
                              : 'Brouillon',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
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
                    onPressed: () => _addOffer(context, ref, record.id),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mes offres',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _addOffer(context, ref, record.id),
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
                    ref.invalidate(businessListingsProvider(record.id)),
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
                                childAspectRatio: columns == 2 ? 0.72 : 0.78,
                              ),
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
          ],
        );
      },
    );
  }

  Future<void> _addOffer(
    BuildContext context,
    WidgetRef ref,
    String businessId,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _AddOfferDialog(businessId: businessId),
    );
    if (created == true) {
      ref.invalidate(businessListingsProvider(businessId));
      ref.invalidate(marketplaceListingsProvider);
    }
  }
}

class _AddOfferDialog extends ConsumerStatefulWidget {
  const _AddOfferDialog({required this.businessId});

  final String businessId;

  @override
  ConsumerState<_AddOfferDialog> createState() => _AddOfferDialogState();
}

class _AddOfferDialogState extends ConsumerState<_AddOfferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  Uint8List? _imageBytes;
  bool _isProduct = true;
  bool _isSubmitting = false;
  bool _isPicking = false;

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
      await ref
          .read(marketplaceRepositoryProvider)
          .addOffer(
            businessId: widget.businessId,
            title: _titleController.text,
            description: _descriptionController.text,
            price: price,
            isProduct: _isProduct,
            imageBytes: _imageBytes,
          );
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
      _message('Impossible d’ajouter cette offre. Réessayez.');
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
      title: const Text('Ajouter une offre'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<bool>(
                  initialValue: _isProduct,
                  decoration: const InputDecoration(labelText: 'Type d’offre'),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Produit')),
                    DropdownMenuItem(value: false, child: Text('Service')),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _isProduct = value ?? true),
                ),
                const SizedBox(height: 12),
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
                    _imageBytes == null ? 'Ajouter une image' : 'Changer',
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
          label: 'Enregistrer',
          isLoading: _isSubmitting,
          expand: false,
          onPressed: _submit,
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
