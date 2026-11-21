import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/image_upload_validation.dart';

class PostRepository {
  PostRepository(this._client);

  static const _uuid = Uuid();

  final SupabaseClient _client;

  Future<List<FeedPost>> fetchFeed({
    required String currentUserId,
    String? authorId,
    List<String>? onlyPostIds,
  }) async {
    if (onlyPostIds != null && onlyPostIds.isEmpty) return const [];
    var query = _client
        .from('posts')
        .select(
          'id, author_id, body, post_type, created_at, '
          'profiles(display_name, avatar_path), '
          'post_media(storage_path, media_type, sort_order)',
        )
        .eq('status', 'published');
    if (authorId != null) {
      query = query.eq('author_id', authorId);
    }
    if (onlyPostIds != null) {
      query = query.inFilter('id', onlyPostIds);
    }
    final rows = await query.order('created_at', ascending: false).limit(50);

    if (rows.isEmpty) return const [];

    final postIds = rows.map((row) => row['id'] as String).toList();
    final counts = await Future.wait([
      _client
          .from('reactions')
          .select('post_id, user_id')
          .inFilter('post_id', postIds),
      _client
          .from('comments')
          .select('post_id')
          .eq('status', 'published')
          .inFilter('post_id', postIds),
      _client
          .from('saved_items')
          .select('item_id')
          .eq('user_id', currentUserId)
          .eq('item_type', 'post')
          .inFilter('item_id', postIds),
    ]);

    final reactionRows = counts[0];
    final commentRows = counts[1];
    final savedRows = counts[2];
    final likeCounts = <String, int>{};
    final likedByCurrentUser = <String>{};
    final commentCounts = <String, int>{};
    final savedPostIds = <String>{};

    for (final reaction in reactionRows) {
      final postId = reaction['post_id'] as String;
      likeCounts.update(postId, (count) => count + 1, ifAbsent: () => 1);
      if (reaction['user_id'] == currentUserId) {
        likedByCurrentUser.add(postId);
      }
    }
    for (final comment in commentRows) {
      final postId = comment['post_id'] as String;
      commentCounts.update(postId, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final savedItem in savedRows) {
      savedPostIds.add(savedItem['item_id'] as String);
    }

    return rows.map((row) {
      final rawProfile = row['profiles'];
      final profile = rawProfile is Map<String, dynamic>
          ? rawProfile
          : const <String, dynamic>{};
      final rawMedia = row['post_media'];
      final media = rawMedia is List
          ? rawMedia.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      media.sort(
        (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0).compareTo(
          (b['sort_order'] as num?)?.toInt() ?? 0,
        ),
      );
      final imagePath = media.isEmpty ? null : media.first['storage_path'];
      final avatarPath = profile['avatar_path'] as String?;
      final postId = row['id'] as String;

      return FeedPost(
        id: postId,
        authorId: row['author_id'] as String,
        authorName: profile['display_name'] as String? ?? 'Étudiant',
        avatarUrl: _publicUrl('avatars', avatarPath),
        body: row['body'] as String,
        postType: row['post_type'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        imageUrl: _publicUrl('post-media', imagePath as String?),
        likeCount: likeCounts[postId] ?? 0,
        commentCount: commentCounts[postId] ?? 0,
        isLikedByCurrentUser: likedByCurrentUser.contains(postId),
        isSavedByCurrentUser: savedPostIds.contains(postId),
      );
    }).toList();
  }

  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final existing = await _client
        .from('reactions')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('reactions').insert({
        'post_id': postId,
        'user_id': userId,
        'reaction_type': 'like',
      });
    } else {
      await _client
          .from('reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    }
  }

  Future<void> toggleSavedPost({
    required String postId,
    required String userId,
  }) async {
    final existing = await _client
        .from('saved_items')
        .select('id')
        .eq('user_id', userId)
        .eq('item_type', 'post')
        .eq('item_id', postId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('saved_items').insert({
        'user_id': userId,
        'item_type': 'post',
        'item_id': postId,
      });
    } else {
      await _client
          .from('saved_items')
          .delete()
          .eq('user_id', userId)
          .eq('item_type', 'post')
          .eq('item_id', postId);
    }
  }

  Future<List<PostComment>> fetchComments(String postId) async {
    final rows = await _client
        .from('comments')
        .select(
          'id, author_id, body, created_at, profiles(display_name, avatar_path)',
        )
        .eq('post_id', postId)
        .eq('status', 'published')
        .order('created_at')
        .limit(100);

    return rows.map((row) {
      final rawProfile = row['profiles'];
      final profile = rawProfile is Map<String, dynamic>
          ? rawProfile
          : const <String, dynamic>{};
      return PostComment(
        id: row['id'] as String,
        authorName: profile['display_name'] as String? ?? 'Étudiant',
        avatarUrl: _publicUrl('avatars', profile['avatar_path'] as String?),
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );
    }).toList();
  }

  Future<void> addComment({
    required String postId,
    required String authorId,
    required String body,
  }) async {
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty || normalizedBody.length > 1000) {
      throw const InvalidPostInputException();
    }
    await _client.from('comments').insert({
      'post_id': postId,
      'author_id': authorId,
      'body': normalizedBody,
    });
  }

  Future<void> createPost({
    required String authorId,
    required String body,
    Uint8List? imageBytes,
  }) async {
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty || normalizedBody.length > 5000) {
      throw const InvalidPostInputException();
    }
    if (imageBytes != null && !isValidImageUpload(imageBytes)) {
      throw const InvalidPostImageException();
    }

    String? storagePath;
    String? postId;

    try {
      if (imageBytes != null) {
        final mimeType = detectImageMimeType(imageBytes)!;
        final extension = mimeType == 'image/png' ? 'png' : 'jpg';
        storagePath = '$authorId/${_uuid.v4()}.$extension';
        await _client.storage
            .from('post-media')
            .uploadBinary(
              storagePath,
              imageBytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: false),
            );
      }

      final post = await _client
          .from('posts')
          .insert({
            'author_id': authorId,
            'body': normalizedBody,
            'post_type': 'general',
          })
          .select('id')
          .single();
      postId = post['id'] as String;

      if (storagePath != null) {
        await _client.from('post_media').insert({
          'post_id': postId,
          'storage_path': storagePath,
          'media_type': 'image',
          'sort_order': 0,
        });
      }
    } catch (error, stackTrace) {
      var rollbackFailed = false;
      if (postId != null) {
        try {
          await _client.from('posts').delete().eq('id', postId);
        } on Exception {
          rollbackFailed = true;
        }
      }
      if (rollbackFailed) {
        throw const PostCreationRollbackException();
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  String? _publicUrl(String bucket, String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.avatarUrl,
    required this.body,
    required this.postType,
    required this.createdAt,
    required this.imageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.isLikedByCurrentUser,
    required this.isSavedByCurrentUser,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? avatarUrl;
  final String body;
  final String postType;
  final DateTime createdAt;
  final String? imageUrl;
  final int likeCount;
  final int commentCount;
  final bool isLikedByCurrentUser;
  final bool isSavedByCurrentUser;
}

class PostComment {
  const PostComment({
    required this.id,
    required this.authorName,
    required this.avatarUrl,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String? avatarUrl;
  final String body;
  final DateTime createdAt;
}

class InvalidPostInputException implements Exception {
  const InvalidPostInputException();
}

class InvalidPostImageException implements Exception {
  const InvalidPostImageException();
}

class PostCreationRollbackException implements Exception {
  const PostCreationRollbackException();
}
