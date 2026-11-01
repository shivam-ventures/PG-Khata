import '../../complaints/domain/complaint_status.dart';
import '../../../shared/widgets/semantic_tone.dart';

/// A rent-to-collect row, e.g. "Rahul Sharma · B-204 · ₹8,500".
class RentTask {
  const RentTask({
    required this.tenantName,
    required this.room,
    required this.amount,
  });

  final String tenantName;
  final String room;
  final int amount;
}

/// An open-complaint row, e.g. "Geyser not working · B-204 · 2 days open".
class ComplaintTask {
  const ComplaintTask({
    required this.title,
    required this.room,
    required this.reportedAt,
    required this.status,
  });

  final String title;
  final String room;
  final DateTime reportedAt;
  final ComplaintStatus status;

  SemanticTone get tone => status.tone;
}

/// Everything the Manager Today screen needs for one selected PG, sourced
/// from `Manager Today.dc.html`'s mock data.
class ManagerTodayData {
  const ManagerTodayData({
    required this.managerFirstName,
    required this.occupiedBeds,
    required this.totalBeds,
    required this.pendingAmount,
    required this.openComplaintsCount,
    required this.rentTasks,
    required this.complaintTasks,
  });

  final String managerFirstName;
  final int occupiedBeds;
  final int totalBeds;
  final int pendingAmount;
  final int openComplaintsCount;
  final List<RentTask> rentTasks;
  final List<ComplaintTask> complaintTasks;

  bool get hasTasks => rentTasks.isNotEmpty || complaintTasks.isNotEmpty;
}
