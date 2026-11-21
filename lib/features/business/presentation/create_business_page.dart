import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_card.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/data/marketplace_repository.dart';

class CreateBusinessPage extends ConsumerStatefulWidget {
  const CreateBusinessPage({super.key});

  @override
  ConsumerState<CreateBusinessPage> createState() => _CreateBusinessPageState();
}

class _CreateBusinessPageState extends ConsumerState<CreateBusinessPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _categoryId;
  int? _wilayaId;
  bool _isSlugEdited = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateSlug(String name) {
    if (_isSlugEdited) return;
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    _slugController.value = TextEditingValue(
      text: slug,
      selection: TextSelection.collapsed(offset: slug.length),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final categoryId = _categoryId;
    if (userId == null || categoryId == null) {
      _showMessage('Session ou catégorie manquante. Reconnectez-vous.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .createBusiness(
            ownerId: userId,
            name: _nameController.text,
            slug: _slugController.text,
            description: _descriptionController.text,
            categoryId: categoryId,
            wilayaId: _wilayaId,
          );
      if (!mounted) return;
      ref.invalidate(myBusinessProvider(userId));
      context.go('/business/manage');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Votre vitrine a été créée.')),
        );
    } on Exception {
      _showMessage(
        'Création impossible. Vérifiez le nom, le lien et réessayez.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.length < 2) return 'Le nom doit contenir au moins 2 caractères.';
    if (name.length > 80) return 'Le nom ne peut pas dépasser 80 caractères.';
    return null;
  }

  String? _validateSlug(String? value) {
    final slug = value?.trim() ?? '';
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
      return 'Utilisez des lettres minuscules, chiffres et tirets.';
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      return const Center(
        child: Text('Connectez-vous pour créer une vitrine.'),
      );
    }

    final existing = ref.watch(myBusinessProvider(userId));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Retour',
              onPressed: () => context.go('/marketplace'),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                'Créer un business',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        existing.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ExistingBusinessError(
            onRetry: () => ref.invalidate(myBusinessProvider(userId)),
          ),
          data: (business) => business != null
              ? _ExistingBusinessCard(
                  business: business,
                  onManage: () => context.go('/business/manage'),
                )
              : ref
                    .watch(businessLookupsProvider)
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) => _ExistingBusinessError(
                        onRetry: () => ref.invalidate(businessLookupsProvider),
                      ),
                      data: _buildForm,
                    ),
        ),
      ],
    );
  }

  Widget _buildForm(BusinessLookups lookups) {
    return SocialCard(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Présentez votre activité aux étudiants. Chaque compte peut '
              'créer une seule vitrine.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              onChanged: (name) => setState(() => _updateSlug(name)),
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              validator: _validateName,
              decoration: const InputDecoration(labelText: 'Nom du business'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _slugController,
              onChanged: (_) => setState(() => _isSlugEdited = true),
              validator: _validateSlug,
              decoration: const InputDecoration(
                labelText: 'Lien de la vitrine',
                prefixText: '',
                helperText: 'Ex. atelier-etudiant',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Lien complet : ${AppConfig.businessUrl(_slugController.text.trim())}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (facultatif)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              validator: (value) =>
                  value == null ? 'Choisissez une catégorie.' : null,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [
                for (final category in lookups.categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _wilayaId,
              decoration: const InputDecoration(
                labelText: 'Wilaya (facultatif)',
              ),
              items: [
                for (final wilaya in lookups.wilayas)
                  DropdownMenuItem(value: wilaya.id, child: Text(wilaya.name)),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _wilayaId = value),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Créer ma vitrine',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExistingBusinessCard extends StatelessWidget {
  const _ExistingBusinessCard({required this.business, required this.onManage});

  final BusinessRecord business;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return SocialCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vous avez déjà une vitrine',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            business.name,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onManage,
            child: const Text('Ouvrir mon tableau de bord'),
          ),
        ],
      ),
    );
  }
}

class _ExistingBusinessError extends StatelessWidget {
  const _ExistingBusinessError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Impossible de charger les catégories.'),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
