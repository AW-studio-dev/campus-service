import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/utils/image_upload_validation.dart';
import '../application/ad_providers.dart';
import '../data/ad_repository.dart';
import 'admin_gate.dart';

class CreateAdPage extends ConsumerStatefulWidget {
  const CreateAdPage({super.key});

  @override
  ConsumerState<CreateAdPage> createState() => _CreateAdPageState();
}

class _CreateAdPageState extends ConsumerState<CreateAdPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  Uint8List? _imageBytes;
  String _placement = 'banner';
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;
  bool _isPickingImage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!isValidImageUpload(bytes)) {
        _showMessage('Choisissez une image JPEG ou PNG de moins de 5 Mo.');
        return;
      }
      if (mounted) setState(() => _imageBytes = bytes);
    } on Exception {
      _showMessage('Impossible de lire cette image.');
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startsAt = DateTime(
          date.year,
          date.month,
          date.day,
          _startsAt.hour,
          _startsAt.minute,
        );
      } else {
        _endsAt = DateTime(
          date.year,
          date.month,
          date.day,
          _endsAt.hour,
          _endsAt.minute,
        );
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    final ownerId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final bytes = _imageBytes;
    if (ownerId == null) {
      _showMessage('Reconnectez-vous pour créer une campagne.');
      return;
    }
    if (bytes == null) {
      _showMessage('Ajoutez une image à la campagne.');
      return;
    }
    if (!_endsAt.isAfter(_startsAt)) {
      _showMessage('La date de fin doit suivre la date de début.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(adRepositoryProvider)
          .createCampaign(
            title: _titleController.text,
            destinationUrl: _urlController.text,
            placement: _placement,
            startsAt: _startsAt,
            endsAt: _endsAt,
            imageBytes: bytes,
            ownerId: ownerId,
          );
      ref.invalidate(manageableAdCampaignsProvider);
      ref.invalidate(adminDashboardStatsProvider);
      if (!mounted) return;
      context.go('/admin/ads');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Campagne créée et envoyée pour validation.'),
          ),
        );
    } on InvalidCampaignImageException {
      _showMessage('Choisissez une image JPEG ou PNG de moins de 5 Mo.');
    } on InvalidCampaignDatesException {
      _showMessage('La date de fin doit suivre la date de début.');
    } on Exception {
      _showMessage('Impossible de créer la campagne. Réessayez.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Créer une campagne',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  validator: (value) {
                    final title = value?.trim() ?? '';
                    return title.length < 2
                        ? 'Saisissez au moins 2 caractères.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL de destination',
                    hintText: 'https://exemple.dz',
                  ),
                  validator: (value) {
                    final uri = Uri.tryParse(value?.trim() ?? '');
                    if (uri == null ||
                        !uri.hasAuthority ||
                        !{'http', 'https'}.contains(uri.scheme)) {
                      return 'Saisissez une URL HTTP ou HTTPS valide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _placement,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'banner',
                      child: Text('Bannière d’accueil'),
                    ),
                    DropdownMenuItem(
                      value: 'sponsored_post',
                      child: Text('Post sponsorisé'),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _placement = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('Début : ${_dateLabel(_startsAt)}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.event_outlined),
                      label: Text('Fin : ${_dateLabel(_endsAt)}'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _imageBytes!,
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  ),
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
                        ? 'Choisir une image'
                        : 'Changer l’image',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Créer et soumettre'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
