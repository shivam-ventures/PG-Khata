import '../../../shared/widgets/semantic_tone.dart';

/// A complaint's lifecycle state. Matches `Manager Complaints.dc.html` and
/// `Tenant Complaints.dc.html`'s shared `STATUS_CLASS` map exactly.
enum ComplaintStatus {
  reported,
  delegated,
  resolved,
  reopened;

  String get label => switch (this) {
    ComplaintStatus.reported => 'Reported',
    ComplaintStatus.delegated => 'Delegated',
    ComplaintStatus.resolved => 'Resolved',
    ComplaintStatus.reopened => 'Reopened',
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
