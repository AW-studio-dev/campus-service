import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/image_upload_validation.dart';

class AdRepository {
  AdRepository(this._client);

  static const _uuid = Uuid();

  final SupabaseClient _client;

  Future<AdminDashboardStats> fetchAdminStats() async {
    final results = await Future.wait<int>([
      _client.from('profiles').count(CountOption.exact),
      _client.from('posts').count(CountOption.exact),
      _client
          .from('ad_campaigns')
          .count(CountOption.exact)
          .eq('status', 'active'),
    ]);
    return AdminDashboardStats(
      users: results[0],
      posts: results[1],
      activeCampaigns: results[2],
    );
  }

  Future<List<AdCampaign>> fetchManageCampaigns() async {
    final rows = await _client
        .from('ad_campaigns')
        .select(
          'id, owner_id, business_id, title, creative_path, destination_url, '
          'placement, post_id, starts_at, ends_at, status, created_at',
        )
        .inFilter('status', ['pending_review', 'active'])
        .order('created_at', ascending: true)
        .limit(100);
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row['id'] as String).toList();
    final statRows = await _client
        .from('ad_campaign_stats')
        .select('campaign_id, impressions, clicks')
        .inFilter('campaign_id', ids);
    final statsByCampaignId = {
      for (final row in statRows) row['campaign_id'] as String: row,
    };
    return rows.map((row) {
      final campaign = _campaignFromRow(row);
      final stats = statsByCampaignId[campaign.id];
      return campaign.copyWith(
        impressions: (stats?['impressions'] as num?)?.toInt() ?? 0,
        clicks: (stats?['clicks'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<AdCampaign>> fetchActiveBanners() async {
    final rows = await _client
        .from('ad_campaigns')
        .select(
          'id, owner_id, business_id, title, creative_path, destination_url, '
          'placement, post_id, starts_at, ends_at, status, created_at',
        )
        .eq('status', 'active')
        .eq('placement', 'banner')
        .order('created_at', ascending: false)
        .limit(20);
    return rows
        .map(_campaignFromRow)
        .where(_isCurrentlyActive)
        .where((campaign) => campaign.imageUrl != null)
        .toList();
  }

  Future<List<AdCampaign>> fetchActiveSponsoredCampaigns() async {
    final rows = await _client
        .from('ad_campaigns')
        .select(
          'id, owner_id, business_id, title, creative_path, destination_url, '
          'placement, post_id, starts_at, ends_at, status, created_at',
        )
        .eq('status', 'active')
        .eq('placement', 'sponsored_post')
        .not('post_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(20);
    return rows.map(_campaignFromRow).where(_isCurrentlyActive).toList();
  }

  Future<List<AdCampaign>> fetchActiveBusinessCampaigns() async {
    final rows = await _client
        .from('ad_campaigns')
        .select(
          'id, owner_id, business_id, title, creative_path, destination_url, '
          'placement, post_id, starts_at, ends_at, status, created_at',
        )
        .eq('status', 'active')
        .not('business_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map(_campaignFromRow).where(_isCurrentlyActive).toList();
  }

  Future<void> setCampaignStatus({
    required String campaignId,
    required String status,
  }) async {
    const allowedStatuses = {'active', 'rejected', 'paused'};
    if (!allowedStatuses.contains(status)) {
      throw const InvalidCampaignStatusException();
    }
    await _client
        .from('ad_campaigns')
        .update({'status': status})
        .eq('id', campaignId);
  }

  Future<String> createCampaign({
    required String title,
    required String destinationUrl,
    required String placement,
    required DateTime startsAt,
    required DateTime endsAt,
    required Uint8List imageBytes,
    required String ownerId,
  }) async {
    if (!isValidImageUpload(imageBytes)) {
      throw const InvalidCampaignImageException();
    }
    if (startsAt.isAfter(endsAt) || startsAt.isAtSameMomentAs(endsAt)) {
      throw const InvalidCampaignDatesException();
    }

    final mimeType = detectImageMimeType(imageBytes)!;
    final extension = mimeType == 'image/png' ? 'png' : 'jpg';
    final imagePath = '$ownerId/${_uuid.v4()}.$extension';
    await _client.storage
        .from('ads-media')
        .uploadBinary(
          imagePath,
          imageBytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    try {
      final result = await _client.rpc(
        'create_ad_campaign',
        params: {
          'p_title': title.trim(),
          'p_creative_path': imagePath,
          'p_destination_url': destinationUrl.trim(),
          'p_placement': placement,
          'p_starts_at': startsAt.toUtc().toIso8601String(),
          'p_ends_at': endsAt.toUtc().toIso8601String(),
        },
      );
      return result as String;
    } catch (error, stackTrace) {
      try {
        await _client.storage.from('ads-media').remove([imagePath]);
      } on Exception {
        // Preserve the campaign creation error; the unused upload can be
        // removed later by storage cleanup.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> recordEvent({
    required String campaignId,
    required String eventType,
  }) async {
    if (eventType != 'impression' && eventType != 'click') {
      throw const InvalidAdEventException();
    }
    await _client.from('ad_events').insert({
      'campaign_id': campaignId,
      'user_id': _client.auth.currentUser?.id,
      'event_type': eventType,
    });
  }

  AdCampaign _campaignFromRow(Map<String, dynamic> row) {
    final creativePath = row['creative_path'] as String?;
    return AdCampaign(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      businessId: row['business_id'] as String?,
      title: row['title'] as String,
      imageUrl: _publicUrl(creativePath),
      destinationUrl: row['destination_url'] as String?,
      placement: row['placement'] as String,
      postId: row['post_id'] as String?,
      startsAt: _dateTime(row['starts_at']),
      endsAt: _dateTime(row['ends_at']),
      status: row['status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  bool _isCurrentlyActive(AdCampaign campaign) {
    final now = DateTime.now();
    return (campaign.startsAt == null || !campaign.startsAt!.isAfter(now)) &&
        (campaign.endsAt == null || campaign.endsAt!.isAfter(now));
  }

  DateTime? _dateTime(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  String? _publicUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return _client.storage.from('ads-media').getPublicUrl(path);
  }
}

class AdCampaign {
  const AdCampaign({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.title,
    required this.imageUrl,
    required this.destinationUrl,
    required this.placement,
    required this.postId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.createdAt,
    this.impressions = 0,
    this.clicks = 0,
  });

  final String id;
  final String ownerId;
  final String? businessId;
  final String title;
  final String? imageUrl;
  final String? destinationUrl;
  final String placement;
  final String? postId;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String status;
  final DateTime createdAt;
  final int impressions;
  final int clicks;

  AdCampaign copyWith({int? impressions, int? clicks}) => AdCampaign(
    id: id,
    ownerId: ownerId,
    businessId: businessId,
    title: title,
    imageUrl: imageUrl,
    destinationUrl: destinationUrl,
    placement: placement,
    postId: postId,
    startsAt: startsAt,
    endsAt: endsAt,
    status: status,
    createdAt: createdAt,
    impressions: impressions ?? this.impressions,
    clicks: clicks ?? this.clicks,
  );
}

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.users,
    required this.posts,
    required this.activeCampaigns,
  });

  final int users;
  final int posts;
  final int activeCampaigns;
}

class InvalidCampaignImageException implements Exception {
  const InvalidCampaignImageException();
}

class InvalidCampaignDatesException implements Exception {
  const InvalidCampaignDatesException();
}

class InvalidCampaignStatusException implements Exception {
  const InvalidCampaignStatusException();
}

class InvalidAdEventException implements Exception {
  const InvalidAdEventException();
}
