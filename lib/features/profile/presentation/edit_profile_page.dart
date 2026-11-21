import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/utils/image_upload_validation.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_card.dart';
import '../../feed/application/post_providers.dart';
import '../application/profile_providers.dart';
import '../data/profile_repository.dart';

class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      return const Center(
        child: Text('Connectez-vous pour modifier votre profil.'),
      );
    }
    final profile = ref.watch(profileProvider(userId));
    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(profileProvider(userId)),
          child: const Text('Impossible de charger le profil. Réessayer'),
        ),
      ),
      data: (record) => record == null
          ? const Center(child: Text('Profil introuvable.'))
          : _EditProfileForm(profile: record),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.profile});

  final ProfileRecord profile;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  late final _nameController = TextEditingController(
    text: widget.profile.displayName,
  );
  late final _bioController = TextEditingController(text: widget.profile.bio);
  Uint8List? _avatarBytes;
  bool _isPicking = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() => _isPicking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!isValidImageUpload(bytes)) {
        _message('Choisissez une image JPEG ou PNG de 5 Mo maximum.');
        return;
      }
      if (mounted) setState(() => _avatarBytes = bytes);
    } on Exception {
      _message('Impossible de lire cette image.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2 || name.length > 80) {
      _message('Le nom doit contenir entre 2 et 80 caractères.');
      return;
    }
    final bio = _bioController.text.trim();
    if (bio.length > 500) {
      _message('La biographie ne peut pas dépasser 500 caractères.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            userId: widget.profile.id,
            displayName: name,
            bio: bio,
            avatarBytes: _avatarBytes,
          );
      if (!mounted) return;
      ref.invalidate(profileProvider(widget.profile.id));
      ref.invalidate(userPostsProvider(widget.profile.id));
      context.go('/profile');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Votre profil a été mis à jour.')),
        );
    } on InvalidProfileImageException {
      _message('L’image doit être JPEG ou PNG et faire 5 Mo maximum.');
    } on Exception {
      _message('Impossible d’enregistrer le profil. Réessayez.');
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Retour au profil',
              onPressed: () => context.go('/profile'),
              icon: const Icon(Icons.arrow_back),
            ),
            Text(
              'Modifier mon profil',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SocialCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _avatarPreview(),
                    IconButton.filled(
                      tooltip: 'Changer la photo',
                      onPressed: _isPicking || _isSaving ? null : _pickAvatar,
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom complet'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Biographie',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Enregistrer',
                isLoading: _isSaving,
                onPressed: _isPicking ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarPreview() {
    if (_avatarBytes != null) {
      return ClipOval(
        child: Image.memory(
          _avatarBytes!,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      );
    }
    return AppAvatar(
      imageUrl: widget.profile.avatarUrl,
      name: widget.profile.displayName,
      size: 96,
    );
  }
}
