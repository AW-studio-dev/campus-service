import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceRequestRepository {
  ServiceRequestRepository(this._client);

  final SupabaseClient _client;

  Future<ServiceRequestOptions> loadOptions() async {
    final results = await Future.wait([
      _client
          .from('study_levels')
          .select('id, name_fr')
          .eq('is_active', true)
          .order('sort_order'),
      _client.from('wilayas').select('id, name_fr').order('id'),
    ]);

    return ServiceRequestOptions(
      studyLevels: (results[0] as List)
          .map(
            (row) => RequestOption(
              id: row['id'] as int,
              label: row['name_fr'] as String,
            ),
          )
          .toList(),
      wilayas: (results[1] as List)
          .map(
            (row) => RequestOption(
              id: row['id'] as int,
              label: row['name_fr'] as String,
            ),
          )
          .toList(),
    );
  }

  Future<void> createRequest({
    required String authorId,
    required String requestType,
    required String title,
    required String description,
    required String format,
    String? subject,
    int? levelId,
    int? wilayaId,
    double? budgetAmount,
  }) async {
    await _client.from('service_requests').insert({
      'author_id': authorId,
      'request_type': requestType,
      'title': title.trim(),
      'description': description.trim(),
      'subject': _emptyToNull(subject),
      'format': format,
      'level_id': levelId,
      'wilaya_id': wilayaId,
      'budget_amount': budgetAmount,
    });
  }

  String? _emptyToNull(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

class ServiceRequestOptions {
  const ServiceRequestOptions({
    required this.studyLevels,
    required this.wilayas,
  });

  final List<RequestOption> studyLevels;
  final List<RequestOption> wilayas;
}

class RequestOption {
  const RequestOption({required this.id, required this.label});

  final int id;
  final String label;
}
