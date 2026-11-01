import 'package:flutter/foundation.dart';

/// One row of `audit_log` — meaningful financial/occupancy/complaint
/// mutations only, written by the payment/complaint/tenancy RPCs
/// (`docs/backend-domain-model.md` §5). Never deleted, so this is a
/// read-only history, not a live status.
@immutable
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.metadata,
    required this.createdAt,
    this.actorName,
  });

  final String id;

  /// Null for a system/scheduled action (e.g. the monthly rent-period cron).
  final String? actorName;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
}
