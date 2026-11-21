import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/ad_providers.dart';
import 'admin_gate.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const AdminGate(child: _AdminDashboardContent());
}

class _AdminDashboardContent extends ConsumerWidget {
  const _AdminDashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminDashboardStatsProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Administration',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Vue d’ensemble de CampusServices.'),
        const SizedBox(height: 20),
        stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Card(
            child: ListTile(
              title: const Text('Impossible de charger les statistiques.'),
              trailing: IconButton(
                tooltip: 'Réessayer',
                onPressed: () => ref.invalidate(adminDashboardStatsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          data: (value) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(label: 'Utilisateurs', value: value.users),
              _StatCard(label: 'Publications', value: value.posts),
              _StatCard(
                label: 'Campagnes actives',
                value: value.activeCampaigns,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/admin/ads'),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Gérer les annonces'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/ads/create'),
              icon: const Icon(Icons.add),
              label: const Text('Créer une campagne'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}
