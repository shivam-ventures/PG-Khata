import '../../../shared/widgets/semantic_tone.dart';

/// A rent period's settlement state. `awaitingConfirmation` and `disputed`
/// apply to any staff-recorded payment (a manager/owner entering it on a
/// tenant's behalf, whatever the method) — only a tenant's own in-app
/// payment settles straight to [paid]. See `PaymentsRepository.recordPayment`
/// vs `recordSelfPayment`.
enum PaymentStatus {
  pending,
  overdue,
  awaitingConfirmation,
  paid,
  disputed;

  String get label => switch (this) {
    PaymentStatus.pending => 'Pending',
    PaymentStatus.overdue => 'Overdue',
    PaymentStatus.awaitingConfirmation => 'Awaiting confirmation',
    PaymentStatus.paid => 'Paid',
    PaymentStatus.disputed => 'Disputed',
  };

  SemanticTone get tone => switch (this) {
    PaymentStatus.pending => SemanticTone.warning,
    PaymentStatus.overdue => SemanticTone.danger,
    PaymentStatus.awaitingConfirmation => SemanticTone.info,
    PaymentStatus.paid => SemanticTone.success,
    PaymentStatus.disputed => SemanticTone.danger,
  };

  /// Whether a manager/owner still needs to collect this period — i.e. it
  /// isn't already paid and isn't sitting with the tenant for confirmation.
  bool get isCollectable =>
      this != PaymentStatus.paid && this != PaymentStatus.awaitingConfirmation;
}
