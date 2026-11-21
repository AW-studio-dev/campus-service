import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_card.dart';
import '../application/service_request_providers.dart';

class HelpRequestPage extends ConsumerStatefulWidget {
  const HelpRequestPage({super.key});

  @override
  ConsumerState<HelpRequestPage> createState() => _HelpRequestPageState();
}

class _HelpRequestPageState extends ConsumerState<HelpRequestPage> {
  static const _requestTypes = [
    ('academic_help', 'Aide scolaire'),
    ('private_tutoring', 'Cours particuliers'),
    ('partner_search', 'Recherche de partenaire'),
    ('project_team', 'Équipe de projet'),
    ('freelance_search', 'Recherche de prestataire'),
    ('other', 'Autre'),
  ];
  static const _formats = [
    ('online', 'En ligne'),
    ('in_person', 'En présentiel'),
    ('hybrid', 'Hybride'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  String _requestType = 'academic_help';
  String _format = 'online';
  int? _levelId;
  int? _wilayaId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      _showMessage('Votre session a expiré. Reconnectez-vous.');
      return;
    }

    final budget = double.tryParse(_budgetController.text.trim());
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(serviceRequestRepositoryProvider)
          .createRequest(
            authorId: userId,
            requestType: _requestType,
            title: _titleController.text,
            description: _descriptionController.text,
            format: _format,
            subject: _subjectController.text,
            levelId: _levelId,
            wilayaId: _wilayaId,
            budgetAmount: budget,
          );
      if (!mounted) return;
      ref.invalidate(serviceRequestOptionsProvider);
      context.go('/home');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Votre demande a été publiée.')),
        );
    } on Exception {
      _showMessage('Impossible de publier la demande. Réessayez.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Ajoutez un titre à votre demande.';
    if (title.length > 150) {
      return 'Le titre ne peut pas dépasser 150 caractères.';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    final description = value?.trim() ?? '';
    if (description.isEmpty) return 'Décrivez votre besoin.';
    if (description.length > 5000) {
      return 'La description ne peut pas dépasser 5 000 caractères.';
    }
    return null;
  }

  String? _validateBudget(String? value) {
    final budgetText = value?.trim() ?? '';
    if (budgetText.isEmpty) return null;
    final budget = double.tryParse(budgetText.replaceAll(',', '.'));
    if (budget == null || budget < 0) {
      return 'Saisissez un montant valide en DZD.';
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
    final options = ref.watch(serviceRequestOptionsProvider);
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
                'Demander de l’aide',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SocialCard(
          padding: const EdgeInsets.all(20),
          child: options.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => _OptionsError(
              onRetry: () => ref.invalidate(serviceRequestOptionsProvider),
            ),
            data: (lookups) => Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Expliquez clairement votre besoin pour que la communauté '
                    'puisse vous aider.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _requestType,
                    decoration: const InputDecoration(
                      labelText: 'Type de demande',
                    ),
                    items: [
                      for (final (value, label) in _requestTypes)
                        DropdownMenuItem(value: value, child: Text(label)),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _requestType = value);
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    maxLength: 150,
                    textCapitalization: TextCapitalization.sentences,
                    validator: _validateTitle,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      hintText: 'Ex. Besoin d’aide en mathématiques',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Matière ou domaine (facultatif)',
                      hintText: 'Ex. Algèbre, programmation, design…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 5000,
                    textCapitalization: TextCapitalization.sentences,
                    validator: _validateDescription,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _levelId,
                    decoration: const InputDecoration(
                      labelText: 'Niveau d’études (facultatif)',
                    ),
                    items: [
                      for (final option in lookups.studyLevels)
                        DropdownMenuItem(
                          value: option.id,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _levelId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _wilayaId,
                    decoration: const InputDecoration(
                      labelText: 'Wilaya (facultatif)',
                    ),
                    items: [
                      for (final option in lookups.wilayas)
                        DropdownMenuItem(
                          value: option.id,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _wilayaId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _format,
                    decoration: const InputDecoration(labelText: 'Format'),
                    items: [
                      for (final (value, label) in _formats)
                        DropdownMenuItem(value: value, child: Text(label)),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _format = value);
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _budgetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validateBudget,
                    decoration: const InputDecoration(
                      labelText: 'Budget indicatif (DZD, facultatif)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: 'Publier la demande',
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionsError extends StatelessWidget {
  const _OptionsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Impossible de charger les niveaux et wilayas.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
