import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../shared/widgets/social_card.dart';
import '../../auth/application/auth_providers.dart';
import '../application/settings_providers.dart';
import '../data/settings_repository.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  NotificationSettings? _editedSettings;
  bool _isSaving = false;
  bool _isSendingReset = false;

  Future<void> _updateSetting(
    String userId,
    NotificationSettings original,
    NotificationSettings updated,
  ) async {
    setState(() {
      _editedSettings = updated;
      _isSaving = true;
    });
    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveNotificationSettings(userId: userId, settings: updated);
      ref.invalidate(notificationSettingsProvider);
    } on Exception {
      if (mounted) {
        setState(() => _editedSettings = original);
        _showMessage('Impossible d’enregistrer ce paramètre.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = ref.read(supabaseClientProvider).auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      _showMessage('Aucune adresse e-mail associée à ce compte.');
      return;
    }
    setState(() => _isSendingReset = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      _showMessage(
        'Si le compte le permet, un e-mail de réinitialisation a été envoyé.',
      );
    } on Exception {
      _showMessage(
        'Impossible de demander la réinitialisation du mot de passe.',
      );
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final settings = ref.watch(notificationSettingsProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Paramètres', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => SocialCard(
            child: Column(
              children: [
                const Text('Impossible de charger les préférences.'),
                TextButton(
                  onPressed: () => ref.invalidate(notificationSettingsProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
          data: (loaded) {
            final value = _editedSettings ?? loaded;
            return SocialCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _PreferenceSwitch(
                    title: 'Messages',
                    subtitle: 'Recevoir les alertes par e-mail.',
                    value: value.emailMessages,
                    enabled: !_isSaving && userId != null,
                    onChanged: (enabled) => _updateSetting(
                      userId!,
                      value,
                      value.copyWith(emailMessages: enabled),
                    ),
                  ),
                  _PreferenceSwitch(
                    title: 'Nouveaux abonnés',
                    subtitle: 'Être informé des nouveaux abonnements.',
                    value: value.emailFollows,
                    enabled: !_isSaving && userId != null,
                    onChanged: (enabled) => _updateSetting(
                      userId!,
                      value,
                      value.copyWith(emailFollows: enabled),
                    ),
                  ),
                  _PreferenceSwitch(
                    title: 'Commentaires',
                    subtitle: 'Alertes pour les commentaires reçus.',
                    value: value.emailComments,
                    enabled: !_isSaving && userId != null,
                    onChanged: (enabled) => _updateSetting(
                      userId!,
                      value,
                      value.copyWith(emailComments: enabled),
                    ),
                  ),
                  _PreferenceSwitch(
                    title: 'Avis sur mon business',
                    subtitle: 'Recevoir les nouveaux avis par e-mail.',
                    value: value.emailReviews,
                    enabled: !_isSaving && userId != null,
                    onChanged: (enabled) => _updateSetting(
                      userId!,
                      value,
                      value.copyWith(emailReviews: enabled),
                    ),
                  ),
                  _PreferenceSwitch(
                    title: 'Actualités et annonces',
                    subtitle: 'Recevoir les communications CampusServices.',
                    value: value.emailMarketing,
                    enabled: !_isSaving && userId != null,
                    onChanged: (enabled) => _updateSetting(
                      userId!,
                      value,
                      value.copyWith(emailMarketing: enabled),
                    ),
                  ),
                  _PreferenceSwitch(
                    title: 'Notifications push',
                    subtitle: 'Activer les notifications sur cet appareil.',
                    value: value.pushEnabled,
                    enabled: !_isSaving && userId != null,
                    onChanged: (enabled) => _updateSetting(
                      userId!,
                      value,
                      value.copyWith(pushEnabled: enabled),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        SocialCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sécurité du compte',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Recevez un e-mail sécurisé pour choisir un nouveau mot de passe.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSendingReset ? null : _sendPasswordReset,
                icon: _isSendingReset
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset_outlined),
                label: const Text('Réinitialiser mon mot de passe'),
              ),
            ],
          ),
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

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}
