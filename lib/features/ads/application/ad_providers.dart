import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/ad_repository.dart';

final adRepositoryProvider = Provider<AdRepository>(
  (ref) => AdRepository(ref.watch(supabaseClientProvider)),
);

final isAdminProvider = FutureProvider<bool>((ref) async {
  final result = await ref
      .watch(supabaseClientProvider)
      .rpc('is_campaign_admin');
  return result == true;
});

final adminDashboardStatsProvider = FutureProvider<AdminDashboardStats>((ref) {
  return ref.watch(adRepositoryProvider).fetchAdminStats();
});

final manageableAdCampaignsProvider = FutureProvider<List<AdCampaign>>((ref) {
  return ref.watch(adRepositoryProvider).fetchManageCampaigns();
});

final activeBannerCampaignsProvider = FutureProvider<List<AdCampaign>>((ref) {
  return ref.watch(adRepositoryProvider).fetchActiveBanners();
});
