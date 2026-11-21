import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/image_upload_validation.dart';

class AuthRepository {
  AuthRepository(this._client);

  static const maxAvatarSizeBytes = maxImageUploadSizeBytes;
  static const _uuid = Uuid();

  final SupabaseClient _client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String displayName,
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
  }

  Future<void> sendPasswordReset(String email) {
    final redirectTo = kIsWeb
        ? Uri.base.replace(fragment: '/reset-password').toString()
        : null;
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<bool> isProfileComplete(String userId) async {
    final profile = await _client
        .from('profiles')
        .select('wilaya_id, university_id, study_level_id')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) {
      throw const ProfileUnavailableException();
    }

    return profile['wilaya_id'] != null &&
        profile['university_id'] != null &&
        profile['study_level_id'] != null;
  }

  Future<OnboardingOptions> loadOnboardingOptions() async {
    final results = await Future.wait([
      _loadWilayas(),
      _loadUniversities(),
      _loadStudyLevels(),
      _loadStudyFields(),
      _loadInterests(),
    ]);

    return OnboardingOptions(
      wilayas: results[0],
      universities: results[1] as List<UniversityOption>,
      studyLevels: results[2],
      studyFields: results[3],
      interests: results[4] as List<InterestOption>,
    );
  }

  Future<void> completeOnboarding({
    required String userId,
    required String displayName,
    required int wilayaId,
    required int universityId,
    required int studyLevelId,
    required int? studyFieldId,
    required String bio,
    required Set<int> interestIds,
    Uint8List? avatarBytes,
  }) async {
    final changes = <String, Object?>{
      'display_name': displayName.trim(),
      'wilaya_id': wilayaId,
      'university_id': universityId,
      'study_level_id': studyLevelId,
      'study_field_id': studyFieldId,
      'bio': bio.trim().isEmpty ? null : bio.trim(),
    };

    if (avatarBytes != null) {
      changes['avatar_path'] = await uploadAvatar(
        userId: userId,
        bytes: avatarBytes,
      );
    }

    final updatedProfile = await _client
        .from('profiles')
        .update(changes)
        .eq('id', userId)
        .select('id')
        .maybeSingle();

    if (updatedProfile == null) {
      throw const ProfileNotUpdatedException();
    }

    await _client.from('user_interests').delete().eq('user_id', userId);
    if (interestIds.isNotEmpty) {
      await _client
          .from('user_interests')
          .insert(
            interestIds
                .map(
                  (interestId) => {
                    'user_id': userId,
                    'interest_id': interestId,
                  },
                )
                .toList(),
          );
    }
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > maxAvatarSizeBytes) {
      throw const UnsupportedAvatarException();
    }

    final mimeType = imageMimeType(bytes);
    if (mimeType == null) {
      throw const UnsupportedAvatarException();
    }

    final extension = mimeType == 'image/png' ? 'png' : 'jpg';
    final path = '$userId/${_uuid.v4()}.$extension';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    return path;
  }

  static String? imageMimeType(Uint8List bytes) {
    return detectImageMimeType(bytes);
  }

  Future<List<LookupOption>> _loadWilayas() async {
    final rows = await _client
        .from('wilayas')
        .select('id, name_fr')
        .order('id');
    return rows
        .map(
          (row) => LookupOption(
            id: row['id'] as int,
            label: row['name_fr'] as String,
          ),
        )
        .toList();
  }

  Future<List<UniversityOption>> _loadUniversities() async {
    final rows = await _client
        .from('universities')
        .select('id, name, wilaya_id')
        .eq('is_active', true)
        .order('name');
    return rows
        .map(
          (row) => UniversityOption(
            id: row['id'] as int,
            label: row['name'] as String,
            wilayaId: row['wilaya_id'] as int,
          ),
        )
        .toList();
  }

  Future<List<LookupOption>> _loadStudyLevels() async {
    final rows = await _client
        .from('study_levels')
        .select('id, name_fr')
        .eq('is_active', true)
        .order('sort_order');
    return rows
        .map(
          (row) => LookupOption(
            id: row['id'] as int,
            label: row['name_fr'] as String,
          ),
        )
        .toList();
  }

  Future<List<LookupOption>> _loadStudyFields() async {
    final rows = await _client
        .from('study_fields')
        .select('id, name_fr')
        .eq('is_active', true)
        .order('sort_order');
    return rows
        .map(
          (row) => LookupOption(
            id: row['id'] as int,
            label: row['name_fr'] as String,
          ),
        )
        .toList();
  }

  Future<List<InterestOption>> _loadInterests() async {
    final rows = await _client
        .from('interests')
        .select('id, name_fr')
        .order('name_fr');
    return rows
        .map(
          (row) => InterestOption(
            id: row['id'] as int,
            label: row['name_fr'] as String,
          ),
        )
        .toList();
  }
}

class OnboardingOptions {
  const OnboardingOptions({
    required this.wilayas,
    required this.universities,
    required this.studyLevels,
    required this.studyFields,
    required this.interests,
  });

  final List<LookupOption> wilayas;
  final List<UniversityOption> universities;
  final List<LookupOption> studyLevels;
  final List<LookupOption> studyFields;
  final List<InterestOption> interests;
}

class LookupOption {
  const LookupOption({required this.id, required this.label});

  final int id;
  final String label;
}

class UniversityOption extends LookupOption {
  const UniversityOption({
    required super.id,
    required super.label,
    required this.wilayaId,
  });

  final int wilayaId;
}

class InterestOption extends LookupOption {
  const InterestOption({required super.id, required super.label});
}

class ProfileUnavailableException implements Exception {
  const ProfileUnavailableException();
}

class ProfileNotUpdatedException implements Exception {
  const ProfileNotUpdatedException();
}

class UnsupportedAvatarException implements Exception {
  const UnsupportedAvatarException();
}
