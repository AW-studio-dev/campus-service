import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(supabaseClientProvider)),
);

final searchResultsProvider =
    FutureProvider.family<List<SearchResult>, SearchFilter>((ref, filter) {
      return ref
          .watch(searchRepositoryProvider)
          .search(query: filter.query, kind: filter.kind);
    });
