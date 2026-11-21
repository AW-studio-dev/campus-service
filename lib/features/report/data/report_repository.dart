import 'package:supabase_flutter/supabase_flutter.dart';

class ReportRepository {
  ReportRepository(this._client);

  final SupabaseClient _client;

  Future<void> submit({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    required String details,
  }) async {
    await _client.from('reports').insert({
      'reporter_id': reporterId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'details': details.trim().isEmpty ? null : details.trim(),
    });
  }
}
