import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/semantic_tone.dart';

/// How urgent a complaint is — set by the tenant when reporting it, per
/// `Tenant Complaints.dc.html`'s severity tiles.
enum ComplaintSeverity {
  low,
  medium,
  high;

  /// Unlocalized — kept only for call sites not yet migrated. Prefer
  /// [labelFor].
  String get label => switch (this) {
    ComplaintSeverity.low => 'Low',
    ComplaintSeverity.medium => 'Medium',
    ComplaintSeverity.high => 'High',
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    ComplaintSeverity.low => l10n.complaintSeverityLow,
    ComplaintSeverity.medium => l10n.complaintSeverityMedium,
    ComplaintSeverity.high => l10n.complaintSeverityHigh,
  };

  SemanticTone get tone => switch (this) {
    ComplaintSeverity.low => SemanticTone.success,
    ComplaintSeverity.medium => SemanticTone.warning,
    ComplaintSeverity.high => SemanticTone.danger,
  };
}
