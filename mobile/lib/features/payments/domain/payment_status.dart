import '../../../l10n/app_localizations.dart';
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
  /// Some, but not all, of this period's amount_due has been confirmed
  /// paid — real e.g. a staff-recorded cash payment covering less than the
  /// full rent, tenant-confirmed. See `rent_period_status` (backend
  /// migration 33): the period's status is derived from the TOTAL of every
  /// confirmed payment against it, not just the latest attempt, so this is
  /// a genuinely distinct state from [paid], not a display nuance.
  partial,
  disputed;

  /// Unlocalized — kept only for call sites not yet migrated. Prefer
  /// [labelFor].
  String get label => switch (this) {
    PaymentStatus.pending => 'Pending',
    PaymentStatus.overdue => 'Overdue',
    PaymentStatus.awaitingConfirmation => 'Awaiting confirmation',
    PaymentStatus.paid => 'Paid',
    PaymentStatus.partial => 'Partially paid',
    PaymentStatus.disputed => 'Disputed',
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    PaymentStatus.pending => l10n.paymentStatusPending,
    PaymentStatus.overdue => l10n.paymentStatusOverdue,
    PaymentStatus.awaitingConfirmation => l10n.paymentStatusAwaitingConfirmation,
    PaymentStatus.paid => l10n.paymentStatusPaid,
    PaymentStatus.partial => l10n.paymentStatusPartial,
    PaymentStatus.disputed => l10n.paymentStatusDisputed,
  };

  SemanticTone get tone => switch (this) {
    PaymentStatus.pending => SemanticTone.warning,
    PaymentStatus.overdue => SemanticTone.danger,
    PaymentStatus.awaitingConfirmation => SemanticTone.info,
    PaymentStatus.paid => SemanticTone.success,
    PaymentStatus.partial => SemanticTone.warning,
    PaymentStatus.disputed => SemanticTone.danger,
  };

  /// Whether a manager/owner still needs to collect (some or all of) this
  /// period — i.e. it isn't fully paid yet and isn't sitting with the
  /// tenant for confirmation. A [partial] period still needs the remaining
  /// balance collected, so it counts as collectable.
  bool get isCollectable =>
      this != PaymentStatus.paid && this != PaymentStatus.awaitingConfirmation;
}
