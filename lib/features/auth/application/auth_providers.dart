import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final onboardingOptionsProvider = FutureProvider<OnboardingOptions>(
  (ref) => ref.watch(authRepositoryProvider).loadOnboardingOptions(),
);
