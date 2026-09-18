import '../../../shared/widgets/semantic_tone.dart';

/// One PG in the Manager's portfolio switcher.
class PgOption {
  const PgOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// A rent-to-collect row, e.g. "Rahul Sharma · B-204 · ₹8,500".
class RentTask {
  const RentTask({
    required this.tenantName,
    required this.room,
    required this.amountLabel,
  });

  final String tenantName;
  final String room;
  final String amountLabel;
}

/// An open-complaint row, e.g. "Geyser not working · B-204 · 2 days open".
class ComplaintTask {
  const ComplaintTask({
    required this.title,
    required this.room,
    required this.age,
    required this.status,
    required this.tone,
  });

  final String title;
  final String room;
  final String age;
  final String status;
  final SemanticTone tone;
}

/// Everything the Manager Today screen needs for one selected PG, sourced
/// from `Manager Today.dc.html`'s mock data.
class ManagerTodayData {
  const ManagerTodayData({
    required this.managerFirstName,
    required this.pgOptions,
    required this.currentPgId,
    required this.occupancyLabel,
    required this.pendingLabel,
    required this.complaintsCountLabel,
    required this.rentTasks,
    required this.complaintTasks,
  });

  final String managerFirstName;
  final List<PgOption> pgOptions;
  final String currentPgId;
  final String occupancyLabel;
  final String pendingLabel;
  final String complaintsCountLabel;
  final List<RentTask> rentTasks;
  final List<ComplaintTask> complaintTasks;

  bool get hasTasks => rentTasks.isNotEmpty || complaintTasks.isNotEmpty;
}
