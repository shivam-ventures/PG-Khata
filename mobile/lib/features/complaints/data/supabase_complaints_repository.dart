import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/complaint.dart';
import '../domain/complaint_category.dart';
import '../domain/complaint_severity.dart';
import '../domain/complaint_status.dart';
import '../domain/time_preference.dart';
import 'complaints_repository.dart';

/// Real backend for [ComplaintsRepository]. Unlike Payments/Tenants, no
/// extra query is needed to display a complaint — `complaints` caches
/// title/status/delegated_to/etc. directly (kept in sync from the
/// append-only `complaint_events` table by a trigger, see
/// `docs/backend-domain-model.md` §3/§7), so one query with two small
/// embeds (property name, tenant name) is enough.
class SupabaseComplaintsRepository implements ComplaintsRepository {
  SupabaseComplaintsRepository(this._client);

  final SupabaseClient _client;

  // tenancy_id is nullable (a common-area complaint has none), so this
  // embed is a plain left join — no `!inner`, unlike the not-null property
  // embed below it.
  static const _selectColumns =
      'id, category, severity, title, room_label, time_preference, '
      'reported_at, status, delegated_to, delegated_at, note, '
      'auto_resolve_days, property_id, tenancy_id, '
      'properties!inner(name), '
      'tenancy:tenancies(tenant:profiles!tenancies_profile_id_fkey(full_name))';

  @override
  Future<Result<List<Complaint>>> fetchComplaints({
    String? propertyId,
    String? tenantId,
  }) async {
    // A blank id shows up briefly for a Manager whose real assigned
    // property hasn't loaded yet (see managerSelectedPgIdProvider) — treat
    // it as "nothing to show" rather than sending an empty string where
    // Postgres expects a uuid, which would fail the cast.
    if (propertyId == '' || tenantId == '') return const Ok([]);
    try {
      final builder = _client.from('complaints').select(_selectColumns);
      final filtered = switch ((propertyId, tenantId)) {
        (final id?, _) => builder.eq('property_id', id),
        (_, final id?) => builder.eq('tenancy_id', id),
        _ => builder,
      };
      final rows = await filtered.order('reported_at', ascending: false);
      return Ok([for (final row in rows) _toComplaint(row)]);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<Complaint>> reportComplaint({
    required String propertyId,
    required String propertyName,
    required String room,
    required String tenantId,
    required String tenantName,
    required ComplaintCategory category,
    required ComplaintSeverity severity,
    required String title,
    required TimePreference timePreference,
    String? idempotencyKey,
  }) async {
    try {
      final created = await _client.rpc(
        'report_complaint',
        params: {
          'p_property_id': propertyId,
          'p_tenancy_id': tenantId,
          'p_category': _categoryToDb(category),
          'p_severity': _severityToDb(severity),
          'p_title': title,
          'p_room_label': room,
          'p_time_preference': _timePreferenceToDb(timePreference),
          if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
        },
      );
      final row = await _client
          .from('complaints')
          .select(_selectColumns)
          .eq('id', (created as Map<String, dynamic>)['id'] as String)
          .single();
      return Ok(_toComplaint(row));
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> delegateComplaint(
    String complaintId, {
    required String assignee,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'delegate_complaint',
        params: {
          'p_complaint_id': complaintId,
          'p_assignee': assignee,
          'p_note': note,
        },
      );
      return const Ok(null);
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> resolveComplaint(String complaintId) async {
    try {
      await _client.rpc(
        'resolve_complaint',
        params: {'p_complaint_id': complaintId},
      );
      return const Ok(null);
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> reopenComplaint(String complaintId) async {
    try {
      await _client.rpc(
        'reopen_complaint',
        params: {'p_complaint_id': complaintId},
      );
      return const Ok(null);
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  Complaint _toComplaint(Map<String, dynamic> row) {
    final property = row['properties'] as Map<String, dynamic>;
    final tenancy = row['tenancy'] as Map<String, dynamic>?;
    final tenant = tenancy?['tenant'] as Map<String, dynamic>?;
    final delegatedAt = row['delegated_at'] as String?;
    return Complaint(
      id: row['id'] as String,
      title: row['title'] as String,
      category: _categoryFromDb(row['category'] as String),
      severity: _severityFromDb(row['severity'] as String),
      propertyId: row['property_id'] as String,
      propertyName: property['name'] as String,
      room: row['room_label'] as String,
      tenantId: row['tenancy_id'] as String?,
      tenantName: tenant?['full_name'] as String? ?? 'Multiple tenants',
      timePreference: _timePreferenceFromDb(row['time_preference'] as String),
      reportedAt: DateTime.parse(row['reported_at'] as String),
      status: _statusFromDb(row['status'] as String),
      delegatedTo: row['delegated_to'] as String?,
      delegatedAt: delegatedAt == null ? null : DateTime.parse(delegatedAt),
      note: row['note'] as String?,
      autoResolveDays: row['auto_resolve_days'] as int,
    );
  }

  String _categoryToDb(ComplaintCategory category) => switch (category) {
    ComplaintCategory.plumbing => 'plumbing',
    ComplaintCategory.electrical => 'electrical',
    ComplaintCategory.wifi => 'wifi',
    ComplaintCategory.cleaning => 'cleaning',
    ComplaintCategory.other => 'other',
  };

  ComplaintCategory _categoryFromDb(String value) => switch (value) {
    'plumbing' => ComplaintCategory.plumbing,
    'electrical' => ComplaintCategory.electrical,
    'wifi' => ComplaintCategory.wifi,
    'cleaning' => ComplaintCategory.cleaning,
    'other' => ComplaintCategory.other,
    _ => throw StateError('Unknown complaint category from database: $value'),
  };

  String _severityToDb(ComplaintSeverity severity) => switch (severity) {
    ComplaintSeverity.low => 'low',
    ComplaintSeverity.medium => 'medium',
    ComplaintSeverity.high => 'high',
  };

  ComplaintSeverity _severityFromDb(String value) => switch (value) {
    'low' => ComplaintSeverity.low,
    'medium' => ComplaintSeverity.medium,
    'high' => ComplaintSeverity.high,
    _ => throw StateError('Unknown complaint severity from database: $value'),
  };

  String _timePreferenceToDb(TimePreference preference) => switch (preference) {
    TimePreference.anytime => 'anytime',
    TimePreference.morning => 'morning',
    TimePreference.afternoon => 'afternoon',
    TimePreference.evening => 'evening',
  };

  TimePreference _timePreferenceFromDb(String value) => switch (value) {
    'anytime' => TimePreference.anytime,
    'morning' => TimePreference.morning,
    'afternoon' => TimePreference.afternoon,
    'evening' => TimePreference.evening,
    _ => throw StateError('Unknown time preference from database: $value'),
  };

  ComplaintStatus _statusFromDb(String value) => switch (value) {
    'reported' => ComplaintStatus.reported,
    'delegated' => ComplaintStatus.delegated,
    'resolved' => ComplaintStatus.resolved,
    'reopened' => ComplaintStatus.reopened,
    _ => throw StateError('Unknown complaint status from database: $value'),
  };
}
