import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

final profileProvider = FutureProvider.family<ProfileRecord?, String>((
  ref,
  profileId,
) {
  final viewerId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  return ref
      .watch(profileRepositoryProvider)
      .fetchProfile(profileId: profileId, viewerId: viewerId);
});
