import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_upload_validation.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_card.dart';
import '../application/post_providers.dart';
import '../data/post_repository.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _bodyController = TextEditingController();
  Uint8List? _imageBytes;
  bool _isPickingImage = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickingImage || _isSubmitting) return;
    setState(() => _isPickingImage = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 88,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!isValidImageUpload(bytes)) {
        _showMessage('Choisissez une image JPEG ou PNG de 5 Mo maximum.');
        return;
      }
      if (mounted) setState(() => _imageBytes = bytes);
    } on Exception {
      _showMessage('Impossible de lire cette image. Choisissez-en une autre.');
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      _showMessage('Votre session a expiré. Reconnectez-vous.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .createPost(
            authorId: userId,
            body: _bodyController.text,
            imageBytes: _imageBytes,
          );
      if (!mounted) return;
      ref.invalidate(feedPostsProvider);
      context.go('/home');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Votre publication a été créée.')),
        );
    } on InvalidPostImageException {
      _showMessage(
        'L’image doit être au format JPEG ou PNG et faire 5 Mo max.',
      );
    } on PostCreationRollbackException {
      _showMessage(
        'La publication n’a pas pu être enregistrée. Réessayez sans image.',
      );
    } on Exception {
      _showMessage(
        'Publication impossible. Vérifiez votre connexion et réessayez.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateBody(String? value) {
    final body = value?.trim() ?? '';
    if (body.isEmpty) return 'Écrivez le contenu de votre publication.';
    if (body.length > 5000) {
      return 'La publication ne peut pas dépasser 5 000 caractères.';
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Retour au fil',
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Créer une publication',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SocialCard(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _bodyController,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  validator: _validateBody,
                  decoration: const InputDecoration(
                    labelText: 'Votre publication',
                    hintText:
                        'Partagez une idée, une question ou une réussite…',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_imageBytes != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _imageBytes!,
                      height: 280,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _imageBytes = null),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Retirer la photo'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isPickingImage || _isSubmitting
                      ? null
                      : _pickImage,
                  icon: _isPickingImage
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined),
                  label: Text(
                    _imageBytes == null
                        ? 'Ajouter une photo'
                        : 'Changer la photo',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Formats JPEG et PNG, 5 Mo maximum.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Publier',
                  isLoading: _isSubmitting,
                  onPressed: _isPickingImage ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
