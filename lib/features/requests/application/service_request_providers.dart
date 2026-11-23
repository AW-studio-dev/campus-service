import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/service_request_repository.dart';

final serviceRequestRepositoryProvider = Provider<ServiceRequestRepository>(
  (ref) => ServiceRequestRepository(ref.watch(supabaseClientProvider)),
);

final serviceRequestOptionsProvider = FutureProvider<ServiceRequestOptions>(
  (ref) => ref.watch(serviceRequestRepositoryProvider).loadOptions(),
);

final myServiceRequestsProvider =
    FutureProvider.family<List<ServiceRequestSummary>, String>((ref, authorId) {
      return ref
          .watch(serviceRequestRepositoryProvider)
          .fetchMyRequests(authorId);
    });
