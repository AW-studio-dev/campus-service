import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_card.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  int _step = 0;
  int? _wilayaId;
  int? _universityId;
  int? _studyLevelId;
  int? _studyFieldId;
  final _interestIds = <int>{};
  Uint8List? _avatarBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final metadataName = ref
        .read(supabaseClientProvider)
        .auth
        .currentUser
        ?.userMetadata?['display_name'];
    _nameController.text = metadataName is String ? metadataName : '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      final size = await image.length();
      if (size == 0 || size > AuthRepository.maxAvatarSizeBytes) {
        _showMessage('L’image doit faire 5 Mo maximum.');
        return;
      }

      final bytes = await image.readAsBytes();
      if (AuthRepository.imageMimeType(bytes) == null) {
        _showMessage('Choisissez une image JPEG ou PNG valide.');
        return;
      }
      setState(() => _avatarBytes = bytes);
    } on PlatformException {
      _showMessage('Impossible de sélectionner cette image.');
    }
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step++);
  }

  void _previousStep() {
    setState(() => _step--);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) {
      context.go('/welcome');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .completeOnboarding(
            userId: user.id,
            displayName: _nameController.text,
            wilayaId: _wilayaId!,
            universityId: _universityId!,
            studyLevelId: _studyLevelId!,
            studyFieldId: _studyFieldId,
            bio: _bioController.text,
            interestIds: _interestIds,
            avatarBytes: _avatarBytes,
          );
      if (mounted) context.go('/home');
    } on PostgrestException {
      _showMessage('Impossible d’enregistrer votre profil. Réessayez.');
    } on StorageException {
      _showMessage('Impossible d’enregistrer votre photo. Réessayez.');
    } on ProfileNotUpdatedException {
      _showMessage('Votre profil n’a pas pu être mis à jour. Réessayez.');
    } on UnsupportedAvatarException {
      _showMessage('Choisissez une image JPEG ou PNG de 5 Mo maximum.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateDisplayName(String? value) {
    final requiredError = AppValidators.requiredText(value);
    if (requiredError != null) return requiredError;
    final length = value!.trim().length;
    if (length < 2 || length > 80) {
      return 'Le nom doit contenir entre 2 et 80 caractères.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(onboardingOptionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Compléter mon profil')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SocialCard(
                padding: const EdgeInsets.all(24),
                child: options.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Impossible de charger les données du formulaire.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            ref.invalidate(onboardingOptionsProvider),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                  data: (data) => _buildForm(data),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(OnboardingOptions options) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Étape ${_step + 1} sur 3',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: (_step + 1) / 3),
          const SizedBox(height: 24),
          if (_step == 0) _buildIdentityStep(),
          if (_step == 1) _buildStudiesStep(options),
          if (_step == 2) _buildInterestsStep(options),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _previousStep,
                    child: const Text('Retour'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                child: _step < 2
                    ? PrimaryButton(label: 'Continuer', onPressed: _nextStep)
                    : PrimaryButton(
                        label: 'Terminer',
                        isLoading: _isSaving,
                        onPressed: _save,
                      ),
              ),
            ],
          ),
          if (_step == 2) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('Terminer sans choisir d’intérêts'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdentityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Comment vous présenter ?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              if (_avatarBytes == null)
                AppAvatar(name: _nameController.text, size: 88)
              else
                CircleAvatar(
                  radius: 44,
                  backgroundImage: MemoryImage(_avatarBytes!),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isSaving ? null : _pickAvatar,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Ajouter une photo (facultatif)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CustomTextField(
          label: 'Nom complet',
          controller: _nameController,
          validator: _validateDisplayName,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          prefixIcon: const Icon(Icons.person_outline),
        ),
      ],
    );
  }

  Widget _buildStudiesStep(OnboardingOptions options) {
    final universities = options.universities
        .where((university) => university.wilayaId == _wilayaId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Votre parcours universitaire',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<int>(
          initialValue: _wilayaId,
          decoration: const InputDecoration(labelText: 'Wilaya'),
          items: options.wilayas
              .map(
                (option) => DropdownMenuItem(
                  value: option.id,
                  child: Text(option.label),
                ),
              )
              .toList(),
          validator: (value) =>
              value == null ? 'Sélectionnez votre wilaya.' : null,
          onChanged: (value) => setState(() {
            _wilayaId = value;
            _universityId = null;
          }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: ValueKey(_wilayaId),
          initialValue: _universityId,
          decoration: const InputDecoration(labelText: 'Université'),
          items: universities
              .map(
                (option) => DropdownMenuItem(
                  value: option.id,
                  child: Text(option.label),
                ),
              )
              .toList(),
          validator: (value) =>
              value == null ? 'Sélectionnez votre établissement.' : null,
          onChanged: _wilayaId == null
              ? null
              : (value) => setState(() => _universityId = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _studyLevelId,
          decoration: const InputDecoration(labelText: 'Niveau d’études'),
          items: options.studyLevels
              .map(
                (option) => DropdownMenuItem(
                  value: option.id,
                  child: Text(option.label),
                ),
              )
              .toList(),
          validator: (value) =>
              value == null ? 'Sélectionnez votre niveau.' : null,
          onChanged: (value) => setState(() => _studyLevelId = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _studyFieldId,
          decoration: const InputDecoration(
            labelText: 'Spécialité (facultatif)',
          ),
          items: options.studyFields
              .map(
                (option) => DropdownMenuItem(
                  value: option.id,
                  child: Text(option.label),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _studyFieldId = value),
        ),
      ],
    );
  }

  Widget _buildInterestsStep(OnboardingOptions options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Qu’est-ce qui vous intéresse ?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Choisissez quelques thèmes pour personnaliser votre expérience. '
          'Cette étape est facultative.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.interests
              .map(
                (interest) => FilterChip(
                  label: Text(interest.label),
                  selected: _interestIds.contains(interest.id),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _interestIds.add(interest.id);
                    } else {
                      _interestIds.remove(interest.id);
                    }
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'À propos de vous (facultatif)',
          controller: _bioController,
          maxLines: 4,
          maxLength: 500,
          textInputAction: TextInputAction.newline,
          hintText: 'Présentez-vous en quelques mots.',
        ),
      ],
    );
  }
}
