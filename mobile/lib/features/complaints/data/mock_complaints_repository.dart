import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/complaint.dart';
import '../domain/complaint_category.dart';
import '../domain/complaint_severity.dart';
import '../domain/complaint_status.dart';
import '../domain/time_preference.dart';
import 'complaints_repository.dart';

/// Phase-5 mock backing for [ComplaintsRepository]. Reconciles `Manager
/// Complaints.dc.html` and `Tenant Complaints.dc.html`'s mock data —
/// "Geyser not working" is the same complaint in both (Rahul Sharma/t7,
/// B-204), so it's seeded once and shows up in both Manager's and his own
/// tenant list. The open count (2: Geyser + the floor-wide wifi complaint)
/// deliberately matches `Manager Today.dc.html`'s already-shipped
/// "2 open" stat — see `MockPaymentsRepository`'s doc comment for why this
/// reconciliation approach matters.
class MockComplaintsRepository implements ComplaintsRepository {
  final List<Complaint> _complaints = [
    Complaint(
      id: 'c1',
      title: 'Geyser not working',
      category: ComplaintCategory.plumbing,
      severity: ComplaintSeverity.high,
      propertyId: 'hsr',
      propertyName: 'HSR PG',
      room: 'B-204',
      tenantId: 't7',
      tenantName: 'Rahul Sharma',
      timePreference: TimePreference.evening,
      reportedAt: DateTime.now().subtract(const Duration(days: 2)),
      status: ComplaintStatus.delegated,
      delegatedTo: 'Electrician',
      delegatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Complaint(
      id: 'c2',
      title: 'Wifi down on 2nd floor',
      category: ComplaintCategory.wifi,
      severity: ComplaintSeverity.medium,
      propertyId: 'hsr',
      propertyName: 'HSR PG',
      room: 'Floor 2',
      tenantName: 'Multiple tenants',
      timePreference: TimePreference.anytime,
      reportedAt: DateTime.now().subtract(const Duration(hours: 5)),
      status: ComplaintStatus.reported,
    ),
    Complaint(
      id: 'c3',
      title: 'Wifi slow in room',
      category: ComplaintCategory.wifi,
      severity: ComplaintSeverity.low,
      propertyId: 'hsr',
      propertyName: 'HSR PG',
      room: 'B-204',
      tenantId: 't7',
      tenantName: 'Rahul Sharma',
      timePreference: TimePreference.anytime,
      reportedAt: DateTime.now().subtract(const Duration(days: 2)),
      status: ComplaintStatus.resolved,
    ),
  ];

  @override
  Future<Result<List<Complaint>>> fetchComplaints({
    String? propertyId,
    String? tenantId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    var scoped = _complaints.toList();
    if (propertyId != null) {
      scoped = scoped.where((c) => c.propertyId == propertyId).toList();
    }
    if (tenantId != null) {
      scoped = scoped.where((c) => c.tenantId == tenantId).toList();
    }
    // High-priority first, matching Manager Complaints.dc.html's sort —
    // it partitions by original severity, not by whether it's still open.
    scoped.sort((a, b) {
      final aHigh = a.severity == ComplaintSeverity.high;
      final bHigh = b.severity == ComplaintSeverity.high;
      if (aHigh == bHigh) return 0;
      return aHigh ? -1 : 1;
    });
    return Ok(List.unmodifiable(scoped));
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
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final complaint = Complaint(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? '${category.label} issue' : title.trim(),
      category: category,
      severity: severity,
      propertyId: propertyId,
      propertyName: propertyName,
      room: room,
      tenantId: tenantId,
      tenantName: tenantName,
      timePreference: timePreference,
      reportedAt: DateTime.now(),
      status: ComplaintStatus.reported,
    );
    _complaints.insert(0, complaint);
    return Ok(complaint);
  }

  @override
  Future<Result<void>> delegateComplaint(
    String complaintId, {
    required String assignee,
    String? note,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index == -1) return const Err(UnexpectedFailure());
    _complaints[index] = _complaints[index].copyWith(
      status: ComplaintStatus.delegated,
      delegatedTo: assignee,
      delegatedAt: DateTime.now(),
      note: note,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> resolveComplaint(String complaintId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index == -1) return const Err(UnexpectedFailure());
    _complaints[index] = _complaints[index].copyWith(
      status: ComplaintStatus.resolved,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> reopenComplaint(String complaintId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index == -1) return const Err(UnexpectedFailure());
    _complaints[index] = _complaints[index].copyWith(
      status: ComplaintStatus.reopened,
    );
    return const Ok(null);
  }
}
