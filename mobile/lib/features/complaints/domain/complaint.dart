import 'package:flutter/foundation.dart';

import 'complaint_category.dart';
import 'complaint_severity.dart';
import 'complaint_status.dart';
import 'time_preference.dart';

/// A tenant-reported issue. Mirrors `docs/domain-model-notes.md`'s Complaint
/// entity — a frontend/domain model, not the eventual Supabase row shape.
///
/// [status] is the last state a person set; [effectiveStatus] is what the
/// UI actually shows — a [ComplaintStatus.delegated] complaint the tenant
/// never reopens auto-resolves after [autoResolveDays], exactly like
/// `Manager Complaints.dc.html`'s `effectiveStatus()` computes it live off
/// `Date.now()` rather than storing a separate "resolved" flag.
@immutable
class Complaint {
  const Complaint({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.propertyId,
    required this.propertyName,
    required this.room,
    required this.tenantName,
    required this.timePreference,
    required this.reportedAt,
    required this.status,
    this.tenantId,
    this.delegatedTo,
    this.delegatedAt,
    this.note,
    this.autoResolveDays = 3,
  });

  final String id;
  final String title;
  final ComplaintCategory category;
  final ComplaintSeverity severity;
  final String propertyId;
  final String propertyName;
  final String room;

  /// Null for a common-area complaint not tied to one tenant (e.g. "Wifi
  /// down on 2nd floor" reported against the whole floor).
  final String? tenantId;
  final String tenantName;
  final TimePreference timePreference;
  final DateTime reportedAt;
  final ComplaintStatus status;
  final String? delegatedTo;
  final DateTime? delegatedAt;
  final String? note;
  final int autoResolveDays;

  ComplaintStatus get effectiveStatus {
    if (status == ComplaintStatus.delegated &&
        delegatedAt != null &&
        DateTime.now().difference(delegatedAt!) >=
            Duration(days: autoResolveDays)) {
      return ComplaintStatus.resolved;
    }
    return status;
  }

  /// Days left before a delegated complaint auto-resolves — 0 once it has.
  int get autoResolveDaysLeft {
    if (delegatedAt == null) return 0;
    final elapsedDays = DateTime.now().difference(delegatedAt!).inDays;
    return (autoResolveDays - elapsedDays).clamp(0, autoResolveDays);
  }

  /// A tenant can say "still not fixed" on a delegated complaint even before
  /// it auto-resolves, or after — matching `Tenant Complaints.dc.html`'s
  /// `canReopen` rule.
  bool get canReopen =>
      effectiveStatus == ComplaintStatus.delegated ||
      effectiveStatus == ComplaintStatus.resolved;

  Complaint copyWith({
    ComplaintStatus? status,
    String? delegatedTo,
    DateTime? delegatedAt,
    String? note,
  }) {
    return Complaint(
      id: id,
      title: title,
      category: category,
      severity: severity,
      propertyId: propertyId,
      propertyName: propertyName,
      room: room,
      tenantId: tenantId,
      tenantName: tenantName,
      timePreference: timePreference,
      reportedAt: reportedAt,
      status: status ?? this.status,
      delegatedTo: delegatedTo ?? this.delegatedTo,
      delegatedAt: delegatedAt ?? this.delegatedAt,
      note: note ?? this.note,
      autoResolveDays: autoResolveDays,
    );
  }
}
