import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';
import '../../../shared/widgets/primary_button.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _hasError = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveSession());
  }

  Future<void> _resolveSession() async {
    if (_isChecking) return;
    _isChecking = true;
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) {
      _isChecking = false;
      if (mounted) context.go('/welcome');
      return;
    }

    try {
      final isComplete = await ref
          .read(authRepositoryProvider)
          .isProfileComplete(user.id);
      if (mounted) context.go(isComplete ? '/home' : '/onboarding');
    } on PostgrestException {
      if (mounted) setState(() => _hasError = true);
    } on ProfileUnavailableException {
      if (mounted) setState(() => _hasError = true);
    } finally {
      _isChecking = false;
    }
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isChecking = false;
    });
    _resolveSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.school_outlined,
                  size: 52,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                const Text('CampusServices', style: AppTypography.logo),
                const SizedBox(height: 8),
                Text(
                  'Your Campus, Your Services.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_hasError) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Impossible de vérifier votre profil. Réessayez.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Réessayer',
                    onPressed: _retry,
                    expand: false,
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
