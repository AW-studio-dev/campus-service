import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/feed/application/post_providers.dart';
import '../../features/marketplace/application/marketplace_providers.dart';
import '../../features/messaging/application/messaging_providers.dart';
import '../../features/notifications/application/notification_providers.dart';
import '../../features/profile/application/profile_providers.dart';
import '../../features/ads/application/ad_providers.dart';
import '../../features/settings/application/settings_providers.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  static const _destinations = [
    _MainDestination('Accueil', Icons.home_outlined),
    _MainDestination('Recherche', Icons.search),
    _MainDestination('Créer', Icons.add_box_outlined),
    _MainDestination('Messages', Icons.chat_bubble_outline),
    _MainDestination('Profil', Icons.person_outline),
  ];

  bool _isSigningOut = false;
  Timer? _notificationRefreshTimer;

  @override
  void initState() {
    super.initState();
    _notificationRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => ref.invalidate(unreadNotificationsCountProvider),
    );
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await ref.read(supabaseClientProvider).auth.signOut();
      _clearUserState();
    } on AuthException {
      _showMessage('La déconnexion a échoué. Réessayez.');
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _clearUserState() {
    ref.invalidate(onboardingOptionsProvider);
    ref.invalidate(feedPostsProvider);
    ref.invalidate(userPostsProvider);
    ref.invalidate(savedPostsProvider);
    ref.invalidate(postCommentsProvider);
    ref.invalidate(inboxProvider);
    ref.invalidate(conversationMessagesProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(myBusinessProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationSettingsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
  }

  @override
  void dispose() {
    _notificationRefreshTimer?.cancel();
    super.dispose();
  }

  void _selectDestination(int index) {
    if (index == 0) {
      context.go('/home');
      return;
    }
    if (index == 2) {
      _showCreateMenu();
      return;
    }
    if (index == 4) {
      context.go('/profile');
      return;
    }
    if (index == 3) {
      context.go('/messages');
      return;
    }
    if (index == 1) {
      context.go('/search');
      return;
    }
    final label = _destinations[index].label.toLowerCase();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('La section $label sera ajoutée ensuite.')),
      );
  }

  void _showCreateMenu() {
    final options = [
      ListTile(
        leading: const Icon(Icons.edit_note_outlined),
        title: const Text('Publier un post'),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/create-post');
        },
      ),
      ListTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Demander de l’aide'),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/help-request');
        },
      ),
    ];
    if (MediaQuery.sizeOf(context).width < 768) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: options),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Créer'),
          content: Column(mainAxisSize: MainAxisSize.min, children: options),
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildHeader(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 768) {
            return _content(maxWidth: 700);
          }
          if (constraints.maxWidth < 1200) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _activeDestination(context),
                  onDestinationSelected: _selectDestination,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _content(maxWidth: 760)),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 248, child: _buildSidebar()),
              const VerticalDivider(width: 1),
              Expanded(child: _content(maxWidth: 760)),
              const VerticalDivider(width: 1),
              const SizedBox(width: 260, child: _RightSidebar()),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 768
          ? NavigationBar(
              selectedIndex: _activeDestination(context),
              onDestinationSelected: _selectDestination,
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    label: destination.label,
                  ),
              ],
            )
          : null,
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 768;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final canManageAds =
        ref.watch(isAdminProvider).whenOrNull(data: (isAdmin) => isAdmin) ??
        false;
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'logo.png',
              width: 38,
              height: 38,
              fit: BoxFit.cover,
            ),
          ),
          if (!isPhone) ...[
            const SizedBox(width: 10),
            Text('CampusServices', style: AppTypography.logo),
          ],
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Marketplace',
          onPressed: () => context.go('/marketplace'),
          icon: const Icon(Icons.storefront_outlined),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.go('/notifications'),
          icon: unreadCount.when(
            loading: () => const Icon(Icons.notifications_none_outlined),
            error: (error, stackTrace) =>
                const Icon(Icons.notifications_none_outlined),
            data: (count) => Badge(
              isLabelVisible: count > 0,
              label: Text(count > 99 ? '99+' : '$count'),
              child: const Icon(Icons.notifications_none_outlined),
            ),
          ),
        ),
        if (canManageAds)
          IconButton(
            tooltip: 'Administration',
            onPressed: () => context.go('/admin'),
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
        IconButton(
          tooltip: 'Paramètres',
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
        IconButton(
          tooltip: 'Se déconnecter',
          onPressed: _isSigningOut ? null : _signOut,
          icon: _isSigningOut
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
        ),
        const SizedBox(width: 8),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }

  int _activeDestination(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path == '/create-post' || path == '/help-request') return 2;
    if (path == '/search') return 1;
    if (path == '/messages') return 3;
    if (path == '/profile') return 4;
    return 0;
  }

  Widget _buildSidebar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('CampusServices', style: AppTypography.logo),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'MENU',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          for (var index = 0; index < _destinations.length; index++)
            ListTile(
              leading: Icon(
                _destinations[index].icon,
                color: index == 0 ? AppColors.primary : AppColors.textSecondary,
              ),
              title: Text(_destinations[index].label),
              selected: index == _activeDestination(context),
              selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () => _selectDestination(index),
            ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text('Se déconnecter'),
            onTap: _isSigningOut ? null : _signOut,
          ),
        ],
      ),
    );
  }

  Widget _content({required double maxWidth}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          children: [
            Expanded(child: widget.child),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Text(
                'Développé par Hami Wissem @ 2026',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightSidebar extends StatelessWidget {
  const _RightSidebar();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('À découvrir', style: AppTypography.textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Partagez des nouvelles, échangez des conseils et faites '
              'grandir votre communauté étudiante.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => GoRouter.of(context).go('/marketplace'),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('Explorer le marketplace'),
        ),
      ],
    );
  }
}

class _MainDestination {
  const _MainDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}
