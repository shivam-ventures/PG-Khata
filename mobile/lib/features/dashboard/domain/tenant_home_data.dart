import '../../../shared/widgets/semantic_tone.dart';

/// One row in the tenant's payment history, e.g. "August 2026 · UPI · Paid".
class PaymentSummary {
  const PaymentSummary({
    required this.periodLabel,
    required this.method,
    required this.date,
    required this.status,
    required this.tone,
  });

  final String periodLabel;
  final String method;
  final String date;
  final String status;
  final SemanticTone tone;
}

/// Everything the Tenant Home screen needs, sourced from `Tenant Home.dc.html`'s
/// mock data.
class TenantHomeData {
  const TenantHomeData({
    required this.firstName,
    required this.pgName,
    required this.pgAddress,
    required this.room,
    required this.managerName,
    required this.managerPhone,
    required this.rentAmountLabel,
    required this.dueLabel,
    required this.nextDueDateLabel,
    required this.isRentDueSoon,
    required this.isOverdue,
    required this.hasPendingCashConfirmation,
    this.pendingCashAmountLabel,
    this.announcement,
    required this.recentPayments,
    this.openComplaintTitle,
    this.openComplaintAge,
    this.openComplaintStatus,
  });

  final String firstName;
  final String pgName;
  final String pgAddress;
  final String room;
  final String managerName;
  final String managerPhone;
  final String rentAmountLabel;

  /// Shown on the due-soon/overdue banner, e.g. "Rent due in 5 days".
  /// Only relevant when [isRentDueSoon] is true.
  final String dueLabel;

  /// Shown on the "all paid up" card, e.g. "28 Sept". Only relevant when
  /// [isRentDueSoon] is false.
  final String nextDueDateLabel;
  final bool isRentDueSoon;
  final bool isOverdue;
  final bool hasPendingCashConfirmation;
  final String? pendingCashAmountLabel;
  final String? announcement;
  final List<PaymentSummary> recentPayments;
  final String? openComplaintTitle;
  final String? openComplaintAge;
  final String? openComplaintStatus;

  bool get hasAnnouncement => announcement != null;
  bool get hasOpenComplaint => openComplaintTitle != null;
}
