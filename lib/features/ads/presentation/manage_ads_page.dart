import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../feed/application/post_providers.dart';
import '../application/ad_providers.dart';
import '../data/ad_repository.dart';
import 'admin_gate.dart';

class ManageAdsPage extends ConsumerWidget {
  const ManageAdsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const AdminGate(child: _ManageAdsContent());
}

class _ManageAdsContent extends ConsumerStatefulWidget {
  const _ManageAdsContent();

  @override
  ConsumerState<_ManageAdsContent> createState() => _ManageAdsContentState();
}

class _ManageAdsContentState extends ConsumerState<_ManageAdsContent> {
  final Set<String> _busyCampaignIds = {};

  Future<void> _setStatus(AdCampaign campaign, String status) async {
    if (_busyCampaignIds.contains(campaign.id)) return;
    setState(() => _busyCampaignIds.add(campaign.id));
    try {
      await ref
          .read(adRepositoryProvider)
          .setCampaignStatus(campaignId: campaign.id, status: status);
      ref.invalidate(manageableAdCampaignsProvider);
      ref.invalidate(adminDashboardStatsProvider);
      ref.invalidate(activeBannerCampaignsProvider);
      ref.invalidate(feedPostsProvider);
      if (mounted) {
        _showMessage(
          status == 'active'
              ? 'Campagne approuvée et activée.'
              : status == 'paused'
              ? 'Campagne suspendue.'
              : 'Campagne refusée.',
        );
      }
    } on Exception {
      if (mounted) _showMessage('Impossible de modifier cette campagne.');
    } finally {
      if (mounted) setState(() => _busyCampaignIds.remove(campaign.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = ref.watch(manageableAdCampaignsProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Modération des annonces',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              tooltip: 'Créer une campagne',
              onPressed: () => context.go('/admin/ads/create'),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        campaigns.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Column(
              children: [
                const Text('Impossible de charger les campagnes.'),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(manageableAdCampaignsProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune campagne à traiter.'),
              );
            }
            final pending = items
                .where((campaign) => campaign.status == 'pending_review')
                .toList();
            final active = items
                .where((campaign) => campaign.status == 'active')
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle(title: 'En attente', count: pending.length),
                if (pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text('Aucune campagne en attente.'),
                  ),
                for (final campaign in pending)
                  _CampaignCard(
                    campaign: campaign,
                    isBusy: _busyCampaignIds.contains(campaign.id),
                    onApprove: () => _setStatus(campaign, 'active'),
                    onReject: () => _setStatus(campaign, 'rejected'),
                  ),
                const SizedBox(height: 20),
                _SectionTitle(title: 'Campagnes actives', count: active.length),
                if (active.isEmpty) const Text('Aucune campagne active.'),
                for (final campaign in active)
                  _CampaignCard(
                    campaign: campaign,
                    isBusy: _busyCampaignIds.contains(campaign.id),
                    onPause: () => _setStatus(campaign, 'paused'),
                  ),
              ],
            );
          },
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      '$title ($count)',
      style: Theme.of(context).textTheme.titleLarge,
    ),
  );
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.campaign,
    required this.isBusy,
    this.onApprove,
    this.onReject,
    this.onPause,
  });

  final AdCampaign campaign;
  final bool isBusy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (campaign.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      campaign.imageUrl!,
                      width: 100,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                            width: 100,
                            height: 72,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${campaign.placement == 'banner' ? 'Bannière' : 'Post sponsorisé'} · ${campaign.status}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        '${campaign.impressions} impressions · ${campaign.clicks} clics',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      if (campaign.destinationUrl != null)
                        Text(
                          campaign.destinationUrl!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onApprove != null)
                  FilledButton(
                    onPressed: isBusy ? null : onApprove,
                    child: const Text('Approuver'),
                  ),
                if (onReject != null)
                  OutlinedButton(
                    onPressed: isBusy ? null : onReject,
                    child: const Text('Refuser'),
                  ),
                if (onPause != null)
                  OutlinedButton(
                    onPressed: isBusy ? null : onPause,
                    child: const Text('Suspendre'),
                  ),
                if (isBusy)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
