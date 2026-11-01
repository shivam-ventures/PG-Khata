import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/audit_log_entry.dart';
import 'audit_log_repository.dart';

class SupabaseAuditLogRepository implements AuditLogRepository {
  SupabaseAuditLogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<AuditLogEntry>>> fetchAuditLog() async {
    try {
      final rows = await _client
          .from('audit_log')
          .select(
            'id, action, entity_type, entity_id, metadata, created_at, '
            'actor:profiles!audit_log_actor_user_id_fkey(full_name)',
          )
          .order('created_at', ascending: false)
          .limit(200);
      return Ok([for (final row in rows) _toEntry(row)]);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  AuditLogEntry _toEntry(Map<String, dynamic> row) {
    final actor = row['actor'] as Map<String, dynamic>?;
    return AuditLogEntry(
      id: row['id'] as String,
      actorName: actor?['full_name'] as String?,
      action: row['action'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      metadata: (row['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
