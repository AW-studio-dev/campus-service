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

  Future<List<ServiceRequestSummary>> fetchMyRequests(String authorId) async {
    final rows = await _client
        .from('service_requests')
        .select(
          'id, title, description, request_type, format, status, subject, '
          'budget_amount, created_at, deadline, '
          'study_levels(name_fr), wilayas(name_fr)',
        )
        .eq('author_id', authorId)
        .order('created_at', ascending: false);
    return rows.map((row) {
      final rawLevel = row['study_levels'];
      final level = rawLevel is Map<String, dynamic>
          ? rawLevel['name_fr'] as String?
          : null;
      final rawWilaya = row['wilayas'];
      final wilaya = rawWilaya is Map<String, dynamic>
          ? rawWilaya['name_fr'] as String?
          : null;
      final amount = row['budget_amount'] as num?;
      return ServiceRequestSummary(
        id: row['id'] as String,
        title: row['title'] as String,
        description: row['description'] as String? ?? '',
        type: row['request_type'] as String,
        format: row['format'] as String,
        status: row['status'] as String,
        subject: row['subject'] as String?,
        level: level,
        wilaya: wilaya,
        budgetAmount: amount?.toDouble(),
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
        deadline: DateTime.tryParse(row['deadline'] as String? ?? ''),
      );
    }).toList();
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

class ServiceRequestSummary {
  const ServiceRequestSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.format,
    required this.status,
    required this.subject,
    required this.level,
    required this.wilaya,
    required this.budgetAmount,
    required this.createdAt,
    required this.deadline,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String format;
  final String status;
  final String? subject;
  final String? level;
  final String? wilaya;
  final double? budgetAmount;
  final DateTime createdAt;
  final DateTime? deadline;
}
