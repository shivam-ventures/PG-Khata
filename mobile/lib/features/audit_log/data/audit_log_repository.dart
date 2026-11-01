import '../../../core/errors/result.dart';
import '../domain/audit_log_entry.dart';

/// The Owner's portfolio-wide audit trail — RLS scopes reads to the
/// signed-in Owner's own org(s) (`is_owner_of_org`), so there's no
/// per-property parameter: an Owner sees every property's history in one
/// list, same as Owner Payments/Complaints.
abstract interface class AuditLogRepository {
  Future<Result<List<AuditLogEntry>>> fetchAuditLog();
}
