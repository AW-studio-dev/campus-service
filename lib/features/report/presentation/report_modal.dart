import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../report/application/report_providers.dart';

class ReportModal extends ConsumerStatefulWidget {
  const ReportModal({
    required this.targetType,
    required this.targetId,
    super.key,
  });

  final String targetType;
  final String targetId;

  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
  }) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) =>
          ReportModal(targetType: targetType, targetId: targetId),
    );
    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Votre signalement a été transmis à la modération.'),
          ),
        );
    }
  }

  @override
  ConsumerState<ReportModal> createState() => _ReportModalState();
}

class _ReportModalState extends ConsumerState<ReportModal> {
  static const _reasons = [
    ('spam', 'Spam ou contenu trompeur'),
    ('inappropriate', 'Contenu inapproprié'),
    ('harassment', 'Harcèlement ou comportement abusif'),
    ('fraud', 'Arnaque ou activité suspecte'),
    ('other', 'Autre'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  String _reason = 'inappropriate';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    final reporterId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (reporterId == null) {
      _showMessage('Connectez-vous pour signaler ce contenu.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(reportRepositoryProvider)
          .submit(
            reporterId: reporterId,
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason,
            details: _detailsController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception {
      _showMessage('Impossible d’envoyer le signalement. Réessayez.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Signaler'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Motif'),
                items: [
                  for (final (value, label) in _reasons)
                    DropdownMenuItem(value: value, child: Text(label)),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value != null) setState(() => _reason = value);
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detailsController,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Détails (facultatif)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        PrimaryButton(
          label: 'Envoyer',
          isLoading: _isSubmitting,
          expand: false,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
