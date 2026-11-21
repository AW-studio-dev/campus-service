import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/ad_providers.dart';
import '../data/ad_repository.dart';

class SponsoredBanner extends ConsumerStatefulWidget {
  const SponsoredBanner({super.key});

  @override
  ConsumerState<SponsoredBanner> createState() => _SponsoredBannerState();
}

class _SponsoredBannerState extends ConsumerState<SponsoredBanner> {
  final Set<String> _impressionCampaignIds = {};

  Future<void> _recordImpression(String campaignId) async {
    try {
      await ref
          .read(adRepositoryProvider)
          .recordEvent(campaignId: campaignId, eventType: 'impression');
    } on Exception catch (error) {
      debugPrint('Ad impression tracking failed: $error');
    }
  }

  Future<void> _openCampaign(AdCampaign campaign) async {
    try {
      await ref
          .read(adRepositoryProvider)
          .recordEvent(campaignId: campaign.id, eventType: 'click');
    } on Exception catch (error) {
      debugPrint('Ad click tracking failed: $error');
    }

    final uri = Uri.tryParse(campaign.destinationUrl ?? '');
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
      _showMessage('Le lien de cette annonce est invalide.');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      _showMessage('Impossible d’ouvrir le lien de cette annonce.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = ref.watch(activeBannerCampaignsProvider);
    return campaigns.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final campaign = items.first;
        if (_impressionCampaignIds.add(campaign.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_recordImpression(campaign.id));
          });
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Material(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surface,
            child: InkWell(
              onTap: () => _openCampaign(campaign),
              child: Stack(
                children: [
                  Image.network(
                    campaign.imageUrl!,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 150,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          'Sponsorisé',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Text(
                          campaign.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
