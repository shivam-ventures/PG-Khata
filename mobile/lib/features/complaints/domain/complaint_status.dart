import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/semantic_tone.dart';

/// A complaint's lifecycle state. Matches `Manager Complaints.dc.html` and
/// `Tenant Complaints.dc.html`'s shared `STATUS_CLASS` map exactly.
enum ComplaintStatus {
  reported,
  delegated,
  resolved,
  reopened;

  /// Unlocalized — kept only for call sites not yet migrated. Prefer
  /// [labelFor].
  String get label => switch (this) {
    ComplaintStatus.reported => 'Reported',
    ComplaintStatus.delegated => 'Delegated',
    ComplaintStatus.resolved => 'Resolved',
    ComplaintStatus.reopened => 'Reopened',
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    ComplaintStatus.reported => l10n.complaintStatusReported,
    ComplaintStatus.delegated => l10n.complaintStatusDelegated,
    ComplaintStatus.resolved => l10n.complaintStatusResolved,
    ComplaintStatus.reopened => l10n.complaintStatusReopened,
  };

  SemanticTone get tone => switch (this) {
    ComplaintStatus.reported => SemanticTone.danger,
    ComplaintStatus.delegated => SemanticTone.warning,
    ComplaintStatus.resolved => SemanticTone.success,
    ComplaintStatus.reopened => SemanticTone.danger,
  };

  /// Whether a newly opened complaint dialog should start in "delegate"
  /// mode (needs an assignee) rather than "view" mode.
  bool get needsDelegation =>
      this == ComplaintStatus.reported || this == ComplaintStatus.reopened;
}
