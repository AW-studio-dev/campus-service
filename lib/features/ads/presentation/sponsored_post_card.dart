import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/ad_providers.dart';
import '../../feed/data/post_repository.dart';

class SponsoredPostCard extends ConsumerStatefulWidget {
  const SponsoredPostCard({required this.post, required this.child, super.key});

  final FeedPost post;
  final Widget child;

  @override
  ConsumerState<SponsoredPostCard> createState() => _SponsoredPostCardState();
}

class _SponsoredPostCardState extends ConsumerState<SponsoredPostCard> {
  String? _impressedCampaignId;

  @override
  void didUpdateWidget(covariant SponsoredPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.campaignId != oldWidget.post.campaignId) {
      _impressedCampaignId = null;
    }
  }

  Future<void> _recordImpression(String campaignId) async {
    try {
      await ref
          .read(adRepositoryProvider)
          .recordEvent(campaignId: campaignId, eventType: 'impression');
    } on Exception catch (error) {
      debugPrint('Ad impression tracking failed: $error');
    }
  }

  Future<void> _openDestination() async {
    final campaignId = widget.post.campaignId;
    if (campaignId == null) return;
    try {
      await ref
          .read(adRepositoryProvider)
          .recordEvent(campaignId: campaignId, eventType: 'click');
    } on Exception catch (error) {
      debugPrint('Ad click tracking failed: $error');
    }
    final uri = Uri.tryParse(widget.post.destinationUrl ?? '');
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
    final campaignId = widget.post.campaignId;
    if (campaignId != null && campaignId != _impressedCampaignId) {
      _impressedCampaignId = campaignId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_recordImpression(campaignId));
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 5),
          child: Row(
            children: [
              const Icon(Icons.campaign_outlined, size: 16),
              const SizedBox(width: 5),
              Text(
                'Sponsorisé',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        widget.child,
        if (widget.post.destinationUrl != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openDestination,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Découvrir'),
            ),
          ),
        ],
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
