import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ads/data/ad_repository.dart';

class SearchRepository {
  SearchRepository(this._client);

  final SupabaseClient _client;

  Future<List<SearchResult>> search({
    required String query,
    required String kind,
  }) async {
    final term = query.trim();
    if (term.length < 2) return const [];
    final pattern = '%${term.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final results = <SearchResult>[];
    final searchBusinesses =
        kind == 'all' || kind == 'business' || kind == 'product';
    final campaignsByBusinessId = <String, AdCampaign>{};
    if (searchBusinesses) {
      final campaigns = await AdRepository(
        _client,
      ).fetchActiveBusinessCampaigns();
      for (final campaign in campaigns) {
        final businessId = campaign.businessId;
        if (businessId != null) {
          campaignsByBusinessId.putIfAbsent(businessId, () => campaign);
        }
      }
    }

    if (kind == 'all' || kind == 'user') {
      final users = await _client
          .from('profiles')
          .select('id, display_name, avatar_path, bio')
          .ilike('display_name', pattern)
          .limit(20);
      results.addAll(
        users.map(
          (row) => SearchResult(
            id: row['id'] as String,
            type: 'user',
            title: row['display_name'] as String,
            description: row['bio'] as String? ?? '',
            imageUrl: _publicUrl('avatars', row['avatar_path'] as String?),
            relatedId: row['id'] as String,
          ),
        ),
      );
    }

    if (kind == 'all' || kind == 'post') {
      final posts = await _client
          .from('posts')
          .select('id, author_id, body, profiles(display_name)')
          .eq('status', 'published')
          .neq('post_type', 'sponsored')
          .ilike('body', pattern)
          .order('created_at', ascending: false)
          .limit(20);
      results.addAll(
        posts.map((row) {
          final rawProfile = row['profiles'];
          final profile = rawProfile is Map<String, dynamic>
              ? rawProfile
              : const <String, dynamic>{};
          return SearchResult(
            id: row['id'] as String,
            type: 'post',
            title: profile['display_name'] as String? ?? 'Étudiant',
            description: row['body'] as String,
            imageUrl: null,
            relatedId: row['author_id'] as String,
          );
        }),
      );
    }

    if (kind == 'all' || kind == 'business') {
      final businesses = await _client
          .from('businesses')
          .select('id, name, description, logo_path')
          .eq('status', 'published')
          .ilike('name', pattern)
          .limit(20);
      results.addAll(
        businesses.map((row) {
          final id = row['id'] as String;
          final campaign = campaignsByBusinessId[id];
          return SearchResult(
            id: id,
            type: 'business',
            title: row['name'] as String,
            description: row['description'] as String? ?? '',
            imageUrl: _publicUrl('business-media', row['logo_path'] as String?),
            relatedId: id,
            campaignId: campaign?.id,
          );
        }),
      );
    }

    if (kind == 'all' || kind == 'product') {
      final products = await _client
          .from('business_products')
          .select(
            'id, business_id, title, description, cover_image_path, '
            'businesses!inner(status)',
          )
          .eq('status', 'available')
          .eq('businesses.status', 'published')
          .ilike('title', pattern)
          .order('created_at', ascending: false)
          .limit(20);
      results.addAll(
        products.map((row) {
          final businessId = row['business_id'] as String;
          final campaign = campaignsByBusinessId[businessId];
          return SearchResult(
            id: row['id'] as String,
            type: 'product',
            title: row['title'] as String,
            description: row['description'] as String? ?? '',
            imageUrl: _publicUrl(
              'business-media',
              row['cover_image_path'] as String?,
            ),
            relatedId: businessId,
            campaignId: campaign?.id,
          );
        }),
      );
    }

    if (kind == 'all' || kind == 'request') {
      final requests = await _client
          .from('service_requests')
          .select('id, author_id, title, description')
          .eq('status', 'open')
          .ilike('title', pattern)
          .limit(20);
      results.addAll(
        requests.map(
          (row) => SearchResult(
            id: row['id'] as String,
            type: 'request',
            title: row['title'] as String,
            description: row['description'] as String? ?? '',
            imageUrl: null,
            relatedId: row['author_id'] as String,
          ),
        ),
      );
    }

    return [
      ...results.where((result) => result.isSponsored),
      ...results.where((result) => !result.isSponsored),
    ];
  }

  String? _publicUrl(String bucket, String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.relatedId,
    this.campaignId,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final String? imageUrl;
  final String relatedId;
  final String? campaignId;

  bool get isSponsored => campaignId != null;
}

class SearchFilter {
  const SearchFilter({required this.query, required this.kind});

  final String query;
  final String kind;

  @override
  bool operator ==(Object other) =>
      other is SearchFilter && other.query == query && other.kind == kind;

  @override
  int get hashCode => Object.hash(query, kind);
}
