import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/image_upload_validation.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  static const _uuid = Uuid();

  final SupabaseClient _client;

  Future<ProfileRecord?> fetchProfile({
    required String profileId,
    required String? viewerId,
  }) async {
    final row = await _client
        .from('profiles')
        .select(
          'id, display_name, avatar_path, bio, created_at, '
          'wilaya_id, university_id, study_level_id, study_field_id, '
          'wilayas(name_fr), universities(name), study_levels(name_fr)',
        )
        .eq('id', profileId)
        .maybeSingle();
    if (row == null) return null;

    final results = await Future.wait([
      _client
          .from('follows')
          .select('follower_id')
          .eq('following_id', profileId),
      _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', profileId),
      _client
          .from('posts')
          .select('id')
          .eq('author_id', profileId)
          .eq('status', 'published'),
    ]);

    var isFollowing = false;
    var isBlockedByViewer = false;
    if (viewerId != null && viewerId != profileId) {
      final relations = await Future.wait([
        _client
            .from('follows')
            .select('follower_id')
            .eq('follower_id', viewerId)
            .eq('following_id', profileId)
            .maybeSingle(),
        _client
            .from('user_blocks')
            .select('blocked_id')
            .eq('blocker_id', viewerId)
            .eq('blocked_id', profileId)
            .maybeSingle(),
      ]);
      isFollowing = relations[0] != null;
      isBlockedByViewer = relations[1] != null;
    }

    final rawWilaya = row['wilayas'];
    final rawUniversity = row['universities'];
    final rawLevel = row['study_levels'];
    return ProfileRecord(
      id: row['id'] as String,
      displayName: row['display_name'] as String,
      avatarUrl: _publicAvatarUrl(row['avatar_path'] as String?),
      bio: row['bio'] as String? ?? '',
      wilaya: rawWilaya is Map<String, dynamic>
          ? rawWilaya['name_fr'] as String?
          : null,
      university: rawUniversity is Map<String, dynamic>
          ? rawUniversity['name'] as String?
          : null,
      studyLevel: rawLevel is Map<String, dynamic>
          ? rawLevel['name_fr'] as String?
          : null,
      postsCount: results[2].length,
      followersCount: results[0].length,
      followingCount: results[1].length,
      isFollowing: isFollowing,
      isBlockedByViewer: isBlockedByViewer,
      wilayaId: row['wilaya_id'] as int?,
      universityId: row['university_id'] as int?,
      studyLevelId: row['study_level_id'] as int?,
      studyFieldId: row['study_field_id'] as int?,
    );
  }

  Future<void> toggleFollow({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) {
      throw const InvalidFollowException();
    }
    final existing = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('follows').insert({
        'follower_id': followerId,
        'following_id': followingId,
      });
    } else {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
    }
  }

  Future<void> setBlocked({
    required String blockerId,
    required String blockedId,
    required bool isBlocked,
  }) async {
    if (blockerId == blockedId) throw const InvalidFollowException();
    final existing = await _client
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId)
        .maybeSingle();
    if (isBlocked && existing == null) {
      await _client.from('user_blocks').insert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
      });
    } else if (!isBlocked && existing != null) {
      await _client
          .from('user_blocks')
          .delete()
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId);
    }
  }

  Future<void> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
    Uint8List? avatarBytes,
    int? wilayaId,
    int? universityId,
    int? studyLevelId,
    int? studyFieldId,
  }) async {
    String? avatarPath;
    if (avatarBytes != null) {
      if (!isValidImageUpload(avatarBytes)) {
        throw const InvalidProfileImageException();
      }
      final mimeType = detectImageMimeType(avatarBytes)!;
      final extension = mimeType == 'image/png' ? 'png' : 'jpg';
      avatarPath = '$userId/${_uuid.v4()}.$extension';
      await _client.storage
          .from('avatars')
          .uploadBinary(
            avatarPath,
            avatarBytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );
    }

    final updates = <String, Object?>{
      'display_name': displayName.trim(),
      'bio': bio.trim().isEmpty ? null : bio.trim(),
      'wilaya_id': wilayaId,
      'university_id': universityId,
      'study_level_id': studyLevelId,
      'study_field_id': studyFieldId,
    };
    if (avatarPath != null) updates['avatar_path'] = avatarPath;
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  String? _publicAvatarUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return _client.storage.from('avatars').getPublicUrl(path);
  }
}

class ProfileRecord {
  const ProfileRecord({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.wilaya,
    required this.university,
    required this.studyLevel,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
    this.isBlockedByViewer = false,
    this.wilayaId,
    this.universityId,
    this.studyLevelId,
    this.studyFieldId,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String bio;
  final String? wilaya;
  final String? university;
  final String? studyLevel;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool isBlockedByViewer;
  final int? wilayaId;
  final int? universityId;
  final int? studyLevelId;
  final int? studyFieldId;
}

class InvalidFollowException implements Exception {
  const InvalidFollowException();
}

class InvalidProfileImageException implements Exception {
  const InvalidProfileImageException();
}
