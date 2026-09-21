import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../data/complaints_repository.dart';
import '../data/mock_complaints_repository.dart';
import '../domain/complaint.dart';
import '../domain/complaint_category.dart';
import '../domain/complaint_severity.dart';
import '../domain/time_preference.dart';

/// The single override point for swapping the complaints data source: point
/// this at a Supabase-backed implementation in Phase 6.
final complaintsRepositoryProvider = Provider<ComplaintsRepository>(
  (ref) => MockComplaintsRepository(),
);

/// A Manager's complaint list for one property.
final managerComplaintsProvider = FutureProvider.family<List<Complaint>, String>(
  (ref, propertyId) async {
    final result = await ref
        .watch(complaintsRepositoryProvider)
        .fetchComplaints(propertyId: propertyId);
    return result.when(ok: (v) => v, err: (failure) => throw failure);
  },
);

/// A single tenant's own complaint list.
final tenantComplaintsProvider = FutureProvider.family<List<Complaint>, String>(
  (ref, tenantId) async {
    final result = await ref
        .watch(complaintsRepositoryProvider)
        .fetchComplaints(tenantId: tenantId);
    return result.when(ok: (v) => v, err: (failure) => throw failure);
  },
);

/// Every complaint across the Owner's whole portfolio — backs the Owner
/// Dashboard's "open complaints" stat and attention items, so that number
/// is drawn from the same ledger Manager Complaints reads instead of a
/// separately-maintained copy.
final portfolioComplaintsProvider = FutureProvider<List<Complaint>>((
  ref,
) async {
  final result = await ref.watch(complaintsRepositoryProvider).fetchComplaints();
  return result.when(ok: (v) => v, err: (failure) => throw failure);
});

void _invalidateComplaints(WidgetRef ref) {
  ref.invalidate(managerComplaintsProvider);
  ref.invalidate(tenantComplaintsProvider);
  ref.invalidate(portfolioComplaintsProvider);
}

Future<AppFailure?> reportComplaint(
  WidgetRef ref, {
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
  final result = await ref
      .read(complaintsRepositoryProvider)
      .reportComplaint(
        propertyId: propertyId,
        propertyName: propertyName,
        room: room,
        tenantId: tenantId,
        tenantName: tenantName,
        category: category,
        severity: severity,
        title: title,
        timePreference: timePreference,
      );
  return result.when(
    ok: (_) {
      _invalidateComplaints(ref);
      return null;
    },
    err: (failure) => failure,
  );
}

Future<AppFailure?> delegateComplaint(
  WidgetRef ref,
  String complaintId, {
  required String assignee,
  String? note,
}) async {
  final result = await ref
      .read(complaintsRepositoryProvider)
      .delegateComplaint(complaintId, assignee: assignee, note: note);
  return result.when(
    ok: (_) {
      _invalidateComplaints(ref);
      return null;
    },
    err: (failure) => failure,
  );
}

Future<AppFailure?> resolveComplaint(WidgetRef ref, String complaintId) async {
  final result = await ref
      .read(complaintsRepositoryProvider)
      .resolveComplaint(complaintId);
  return result.when(
    ok: (_) {
      _invalidateComplaints(ref);
      return null;
    },
    err: (failure) => failure,
  );
}

Future<AppFailure?> reopenComplaint(WidgetRef ref, String complaintId) async {
  final result = await ref
      .read(complaintsRepositoryProvider)
      .reopenComplaint(complaintId);
  return result.when(
    ok: (_) {
      _invalidateComplaints(ref);
      return null;
    },
    err: (failure) => failure,
  );
}
