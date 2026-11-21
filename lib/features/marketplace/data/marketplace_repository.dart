import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/image_upload_validation.dart';

class MarketplaceRepository {
  MarketplaceRepository(this._client);

  static const _uuid = Uuid();

  final SupabaseClient _client;

  Future<List<MarketplaceCategory>> loadCategories() async {
    final rows = await _client
        .from('categories')
        .select('id, name_fr, kind')
        .eq('is_active', true)
        .order('sort_order')
        .order('name_fr');
    return rows
        .map(
          (row) => MarketplaceCategory(
            id: row['id'] as int,
            name: row['name_fr'] as String,
            kind: row['kind'] as String,
          ),
        )
        .toList();
  }

  Future<List<MarketplaceListing>> loadListings({
    int? categoryId,
    String kind = 'all',
  }) async {
    final listings = <MarketplaceListing>[];
    if (kind == 'all' || kind == 'product') {
      var query = _client
          .from('business_products')
          .select(
            'id, business_id, title, description, price_amount, currency, '
            'cover_image_path, created_at, businesses!inner(id, name, slug, owner_id, '
            'category_id, logo_path, status)',
          )
          .eq('status', 'available')
          .eq('businesses.status', 'published');
      if (categoryId != null) {
        query = query.eq('businesses.category_id', categoryId);
      }
      final rows = await query.order('created_at', ascending: false).limit(60);
      listings.addAll(rows.map((row) => _listingFromRow(row, isProduct: true)));
    }

    if (kind == 'all' || kind == 'service') {
      var query = _client
          .from('business_services')
          .select(
            'id, business_id, title, description, price_amount, currency, '
            'cover_image_path, created_at, businesses!inner(id, name, slug, owner_id, '
            'category_id, logo_path, status)',
          )
          .eq('status', 'available')
          .eq('businesses.status', 'published');
      if (categoryId != null) {
        query = query.eq('businesses.category_id', categoryId);
      }
      final rows = await query.order('created_at', ascending: false).limit(60);
      listings.addAll(
        rows.map((row) => _listingFromRow(row, isProduct: false)),
      );
    }

    listings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return listings;
  }

  Future<MarketplaceListing?> fetchListing({
    required String listingId,
    required bool isProduct,
  }) async {
    final table = isProduct ? 'business_products' : 'business_services';
    final row = await _client
        .from(table)
        .select(
          'id, business_id, title, description, price_amount, currency, '
          'cover_image_path, businesses!inner(id, name, slug, owner_id, '
          'category_id, logo_path, status)',
        )
        .eq('id', listingId)
        .eq('status', 'available')
        .eq('businesses.status', 'published')
        .maybeSingle();
    if (row == null) return null;
    return _listingFromRow(row, isProduct: isProduct);
  }

  Future<BusinessRecord?> fetchBusiness(String businessId) async {
    final row = await _client
        .from('businesses')
        .select(
          'id, owner_id, name, slug, description, logo_path, cover_path, '
          'category_id, wilaya_id, status',
        )
        .eq('id', businessId)
        .maybeSingle();
    return row == null ? null : _businessFromRow(row);
  }

  Future<BusinessRecord?> fetchMyBusiness(String ownerId) async {
    final row = await _client
        .from('businesses')
        .select(
          'id, owner_id, name, slug, description, logo_path, cover_path, '
          'category_id, wilaya_id, status',
        )
        .eq('owner_id', ownerId)
        .maybeSingle();
    return row == null ? null : _businessFromRow(row);
  }

  Future<BusinessLookups> loadBusinessLookups() async {
    final results = await Future.wait([
      _client
          .from('categories')
          .select('id, name_fr')
          .eq('is_active', true)
          .order('name_fr'),
      _client.from('wilayas').select('id, name_fr').order('id'),
    ]);
    return BusinessLookups(
      categories: (results[0] as List)
          .map(
            (row) => MarketplaceCategory(
              id: row['id'] as int,
              name: row['name_fr'] as String,
              kind: 'business',
            ),
          )
          .toList(),
      wilayas: (results[1] as List)
          .map(
            (row) => MarketplaceCategory(
              id: row['id'] as int,
              name: row['name_fr'] as String,
              kind: 'wilaya',
            ),
          )
          .toList(),
    );
  }

  Future<BusinessRecord> createBusiness({
    required String ownerId,
    required String name,
    required String slug,
    required String description,
    required int categoryId,
    int? wilayaId,
  }) async {
    final row = await _client
        .from('businesses')
        .insert({
          'owner_id': ownerId,
          'name': name.trim(),
          'slug': slug.trim().toLowerCase(),
          'description': _emptyToNull(description),
          'category_id': categoryId,
          'wilaya_id': wilayaId,
          'status': 'published',
        })
        .select(
          'id, owner_id, name, slug, description, logo_path, cover_path, '
          'category_id, wilaya_id, status',
        )
        .single();
    return _businessFromRow(row);
  }

  Future<List<MarketplaceListing>> fetchBusinessListings(
    String businessId,
  ) async {
    final results = await Future.wait([
      _client
          .from('business_products')
          .select(
            'id, business_id, title, description, price_amount, currency, '
            'cover_image_path, created_at, businesses!inner(id, name, slug, '
            'owner_id, category_id, logo_path, status)',
          )
          .eq('business_id', businessId)
          .eq('status', 'available')
          .order('created_at', ascending: false),
      _client
          .from('business_services')
          .select(
            'id, business_id, title, description, price_amount, currency, '
            'cover_image_path, created_at, businesses!inner(id, name, slug, '
            'owner_id, category_id, logo_path, status)',
          )
          .eq('business_id', businessId)
          .eq('status', 'available')
          .order('created_at', ascending: false),
    ]);
    final listings = <MarketplaceListing>[
      ...(results[0] as List).map(
        (row) => _listingFromRow(row, isProduct: true),
      ),
      ...(results[1] as List).map(
        (row) => _listingFromRow(row, isProduct: false),
      ),
    ];
    listings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return listings;
  }

  Future<List<BusinessReview>> fetchBusinessReviews(String businessId) async {
    final rows = await _client
        .from('reviews')
        .select(
          'id, reviewer_id, rating, comment, created_at, profiles(display_name, avatar_path)',
        )
        .eq('business_id', businessId)
        .eq('status', 'published')
        .order('created_at', ascending: false);
    return rows.map((row) {
      final rawProfile = row['profiles'];
      final profile = rawProfile is Map<String, dynamic>
          ? rawProfile
          : const <String, dynamic>{};
      return BusinessReview(
        id: row['id'] as String,
        reviewerId: row['reviewer_id'] as String,
        reviewerName: profile['display_name'] as String? ?? 'Étudiant',
        rating: row['rating'] as int,
        comment: row['comment'] as String? ?? '',
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );
    }).toList();
  }

  Future<void> submitReview({
    required String reviewerId,
    required String businessId,
    required int rating,
    required String comment,
  }) async {
    if (rating < 1 || rating > 5) throw const InvalidBusinessReviewException();
    await _client.from('reviews').insert({
      'reviewer_id': reviewerId,
      'business_id': businessId,
      'rating': rating,
      'comment': _emptyToNull(comment),
      'status': 'published',
    });
  }

  Future<void> updateBusinessBranding({
    required String businessId,
    Uint8List? logoBytes,
    Uint8List? coverBytes,
  }) async {
    final changes = <String, Object?>{};
    if (logoBytes != null) {
      changes['logo_path'] = await _uploadBusinessImage(
        businessId: businessId,
        bytes: logoBytes,
      );
    }
    if (coverBytes != null) {
      changes['cover_path'] = await _uploadBusinessImage(
        businessId: businessId,
        bytes: coverBytes,
      );
    }
    if (changes.isEmpty) return;
    await _client.from('businesses').update(changes).eq('id', businessId);
  }

  Future<String> _uploadBusinessImage({
    required String businessId,
    required Uint8List bytes,
  }) async {
    if (!isValidImageUpload(bytes)) {
      throw const InvalidBusinessImageException();
    }
    final mimeType = detectImageMimeType(bytes)!;
    final extension = mimeType == 'image/png' ? 'png' : 'jpg';
    final path = '$businessId/${_uuid.v4()}.$extension';
    await _client.storage
        .from('business-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    return path;
  }

  Future<void> addOffer({
    required String businessId,
    required String title,
    required String description,
    required double? price,
    required bool isProduct,
    Uint8List? imageBytes,
  }) async {
    if (imageBytes != null && !isValidImageUpload(imageBytes)) {
      throw const InvalidBusinessImageException();
    }

    String? imagePath;
    if (imageBytes != null) {
      final mimeType = detectImageMimeType(imageBytes)!;
      final extension = mimeType == 'image/png' ? 'png' : 'jpg';
      imagePath = '$businessId/${_uuid.v4()}.$extension';
      await _client.storage
          .from('business-media')
          .uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );
    }

    final table = isProduct ? 'business_products' : 'business_services';
    await _client.from(table).insert({
      'business_id': businessId,
      'title': title.trim(),
      'description': _emptyToNull(description),
      'price_amount': price,
      'currency': 'DZD',
      'cover_image_path': imagePath,
      'status': 'available',
    });
  }

  MarketplaceListing _listingFromRow(
    Map<String, dynamic> row, {
    required bool isProduct,
  }) {
    final rawBusiness = row['businesses'];
    final business = rawBusiness is Map<String, dynamic>
        ? rawBusiness
        : const <String, dynamic>{};
    final amount = row['price_amount'] as num?;
    return MarketplaceListing(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      businessOwnerId: business['owner_id'] as String? ?? '',
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      businessName: business['name'] as String? ?? 'Business étudiant',
      businessSlug: business['slug'] as String? ?? '',
      priceAmount: amount?.toDouble(),
      currency: row['currency'] as String? ?? 'DZD',
      isProduct: isProduct,
      imageUrl: _publicUrl(
        'business-media',
        row['cover_image_path'] as String?,
      ),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  BusinessRecord _businessFromRow(Map<String, dynamic> row) {
    return BusinessRecord(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      name: row['name'] as String,
      slug: row['slug'] as String,
      description: row['description'] as String? ?? '',
      logoUrl: _publicUrl('business-media', row['logo_path'] as String?),
      coverUrl: _publicUrl('business-media', row['cover_path'] as String?),
      categoryId: row['category_id'] as int?,
      wilayaId: row['wilaya_id'] as int?,
      status: row['status'] as String,
    );
  }

  String? _publicUrl(String bucket, String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  String? _emptyToNull(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

class MarketplaceCategory {
  const MarketplaceCategory({
    required this.id,
    required this.name,
    required this.kind,
  });

  final int id;
  final String name;
  final String kind;
}

class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.businessId,
    required this.businessOwnerId,
    required this.title,
    required this.description,
    required this.businessName,
    required this.businessSlug,
    required this.priceAmount,
    required this.currency,
    required this.isProduct,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String businessOwnerId;
  final String title;
  final String description;
  final String businessName;
  final String businessSlug;
  final double? priceAmount;
  final String currency;
  final bool isProduct;
  final String? imageUrl;
  final DateTime createdAt;
}

class BusinessRecord {
  const BusinessRecord({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    required this.description,
    required this.logoUrl,
    required this.coverUrl,
    required this.categoryId,
    required this.wilayaId,
    required this.status,
  });

  final String id;
  final String ownerId;
  final String name;
  final String slug;
  final String description;
  final String? logoUrl;
  final String? coverUrl;
  final int? categoryId;
  final int? wilayaId;
  final String status;
}

class BusinessLookups {
  const BusinessLookups({required this.categories, required this.wilayas});

  final List<MarketplaceCategory> categories;
  final List<MarketplaceCategory> wilayas;
}

class BusinessReview {
  const BusinessReview({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String reviewerId;
  final String reviewerName;
  final int rating;
  final String comment;
  final DateTime createdAt;
}

class InvalidBusinessImageException implements Exception {
  const InvalidBusinessImageException();
}

class InvalidBusinessReviewException implements Exception {
  const InvalidBusinessReviewException();
}
