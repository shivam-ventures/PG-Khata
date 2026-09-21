import '../../../core/errors/result.dart';
import '../domain/complaint.dart';
import '../domain/complaint_category.dart';
import '../domain/complaint_severity.dart';
import '../domain/time_preference.dart';

/// The complaint ledger. [fetchComplaints] backs both the Manager's
/// per-property list (pass [propertyId]) and a Tenant's own list (pass
/// [tenantId]) — exactly one should be given. Swap the implementation for a
/// Supabase-backed one in Phase 6.
abstract interface class ComplaintsRepository {
  Future<Result<List<Complaint>>> fetchComplaints({
    String? propertyId,
    String? tenantId,
  });

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
  });

  Future<Result<void>> delegateComplaint(
    String complaintId, {
    required String assignee,
    String? note,
  });

  Future<Result<void>> resolveComplaint(String complaintId);

  Future<Result<void>> reopenComplaint(String complaintId);
}
