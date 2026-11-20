import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_card.dart';
import '../application/auth_providers.dart';
import 'auth_error_presenter.dart';

class VerifyOtpRouteArgs {
  const VerifyOtpRouteArgs({
    required this.email,
    this.startResendCooldown = false,
  });

  final String email;
  final bool startResendCooldown;
}

class VerifyOtpPage extends ConsumerStatefulWidget {
  const VerifyOtpPage({
    required this.email,
    this.startResendCooldown = false,
    super.key,
  });

  final String email;
  final bool startResendCooldown;

  @override
  ConsumerState<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends ConsumerState<VerifyOtpPage> {
  static const _resendCooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  Timer? _cooldownTimer;
  int _remainingSeconds = _resendCooldownSeconds;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    if (widget.email.trim().isEmpty || !widget.startResendCooldown) {
      _remainingSeconds = 0;
    } else {
      _startCooldownTimer();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (widget.email.trim().isEmpty || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .verifySignupOtp(email: widget.email, token: _codeController.text);
      if (!mounted) return;

      if (response.session == null) {
        _showMessage(
          'Le code a été vérifié, mais la session n’a pas pu être ouverte. '
          'Connectez-vous pour continuer.',
        );
        context.go('/login');
        return;
      }

      context.go('/splash');
    } on AuthException catch (error) {
      _showMessage(authErrorMessage(error, operation: AuthOperation.verifyOtp));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_remainingSeconds > 0) {
      _showMessage('Veuillez attendre $_remainingSeconds secondes.');
      return;
    }
    if (widget.email.trim().isEmpty) {
      _showMessage('Adresse e-mail manquante. Recommencez l’inscription.');
      return;
    }

    setState(() {
      _isResending = true;
      _remainingSeconds = _resendCooldownSeconds;
    });
    _startCooldownTimer();
    try {
      await ref.read(authRepositoryProvider).resendSignupOtp(widget.email);
      if (!mounted) return;
      _showMessage('Un nouveau code a été envoyé.');
    } on AuthException catch (error) {
      _showMessage(authErrorMessage(error, operation: AuthOperation.resendOtp));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        timer.cancel();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String? _validateCode(String? value) {
    if (value == null || !RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Saisissez le code à 6 chiffres.';
    }
    return null;
  }

  String _resendLabel() {
    if (_remainingSeconds == 0) return 'Renvoyer le code';
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return 'Renvoyer dans $minutes:$seconds';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final emailMissing = widget.email.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => context.go('/register'),
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
                child: emailMissing
                    ? _buildMissingEmail(context)
                    : _buildVerificationForm(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissingEmail(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Adresse e-mail introuvable',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Recommencez l’inscription pour recevoir un code de vérification.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => context.go('/register'),
          child: const Text('Retour à l’inscription'),
        ),
      ],
    );
  }

  Widget _buildVerificationForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vérifier votre adresse e-mail',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Un code de vérification a été envoyé à ${widget.email}.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: _validateCode,
            onFieldSubmitted: (_) => _verify(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              letterSpacing: 8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: const InputDecoration(
              labelText: 'Code à 6 chiffres',
              hintText: '000000',
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Vérifier',
            isLoading: _isVerifying,
            onPressed: _isResending ? null : _verify,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isResending || _isVerifying || _remainingSeconds > 0
                ? null
                : _resend,
            child: Text(_isResending ? 'Envoi…' : _resendLabel()),
          ),
        ],
      ),
    );
  }
}
