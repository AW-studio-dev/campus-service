import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_card.dart';
import '../application/auth_providers.dart';
import 'auth_error_presenter.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isLoading = false;
  bool _isUpdated = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirmez votre nouveau mot de passe.';
    }
    if (value != _passwordController.text) {
      return 'Les mots de passe ne correspondent pas.';
    }
    return null;
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordController.text);
      if (mounted) setState(() => _isUpdated = true);
    } on AuthException catch (error) {
      _showMessage(
        authErrorMessage(error, operation: AuthOperation.updatePassword),
      );
    } on Exception {
      _showMessage('Impossible de modifier le mot de passe. Réessayez.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSession =
        ref.watch(supabaseClientProvider).auth.currentSession != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour à la connexion',
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SocialCard(
                padding: const EdgeInsets.all(24),
                child: !hasSession
                    ? _buildInvalidLink(context)
                    : _isUpdated
                    ? _buildSuccess(context)
                    : _buildForm(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidLink(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lien invalide ou expiré',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Demandez un nouveau lien depuis la page de connexion, puis ouvrez '
          'le lien reçu par e-mail.',
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Retour à la connexion',
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mot de passe modifié',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text('Votre nouveau mot de passe est enregistré.'),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Continuer',
          onPressed: () => context.go('/splash'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choisir un nouveau mot de passe',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('Saisissez et confirmez votre nouveau mot de passe.'),
          const SizedBox(height: 20),
          CustomTextField(
            label: 'Nouveau mot de passe',
            controller: _passwordController,
            validator: AppValidators.password,
            obscureText: _hidePassword,
            enabled: !_isLoading,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _hidePassword
                  ? 'Afficher le mot de passe'
                  : 'Masquer le mot de passe',
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Confirmer le nouveau mot de passe',
            controller: _confirmationController,
            validator: _validateConfirmation,
            obscureText: _hideConfirmation,
            enabled: !_isLoading,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _hideConfirmation
                  ? 'Afficher le mot de passe'
                  : 'Masquer le mot de passe',
              onPressed: () =>
                  setState(() => _hideConfirmation = !_hideConfirmation),
              icon: Icon(
                _hideConfirmation
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Enregistrer le nouveau mot de passe',
            isLoading: _isLoading,
            onPressed: _updatePassword,
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
