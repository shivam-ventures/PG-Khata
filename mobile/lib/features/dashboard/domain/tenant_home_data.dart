import '../../complaints/domain/complaint_status.dart';
import '../../payments/domain/payment_method.dart';
import '../../payments/domain/payment_status.dart';
import '../../../shared/widgets/semantic_tone.dart';

/// One row in the tenant's payment history, e.g. "August 2026 · UPI · Paid".
class PaymentSummary {
  const PaymentSummary({
    required this.periodMonth,
    required this.method,
    required this.paidDate,
    required this.status,
  });

  final DateTime periodMonth;
  final PaymentMethod? method;
  final DateTime paidDate;
  final PaymentStatus status;

  SemanticTone get tone => status.tone;
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
    this.managerPhone,
    required this.rentAmount,
    this.currentDueDate,
    required this.isRentDueSoon,
    required this.isOverdue,
    required this.hasPendingCashConfirmation,
    this.pendingCashAmount,
    this.announcement,
    required this.recentPayments,
    this.openComplaintTitle,
    this.openComplaintReportedAt,
    this.openComplaintStatus,
  });

  final String firstName;
  final String pgName;
  final String pgAddress;
  final String room;
  final String managerName;
  final String? managerPhone;
  final int rentAmount;

  /// The current rent period's due date, if a period exists. When
  /// [isRentDueSoon] is true this is the date rent is due; otherwise it's
  /// the last paid period's due date, from which the *next* period's due
  /// date is derived at render time.
  final DateTime? currentDueDate;

  final bool isRentDueSoon;
  final bool isOverdue;
  final bool hasPendingCashConfirmation;
  final int? pendingCashAmount;
  final String? announcement;
  final List<PaymentSummary> recentPayments;
  final String? openComplaintTitle;
  final DateTime? openComplaintReportedAt;
  final ComplaintStatus? openComplaintStatus;

  bool get hasAnnouncement => announcement != null;
  bool get hasOpenComplaint => openComplaintTitle != null;
}
