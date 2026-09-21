import '../../../shared/widgets/semantic_tone.dart';

/// How urgent a complaint is — set by the tenant when reporting it, per
/// `Tenant Complaints.dc.html`'s severity tiles.
enum ComplaintSeverity {
  low,
  medium,
  high;

  String get label => switch (this) {
    ComplaintSeverity.low => 'Low',
    ComplaintSeverity.medium => 'Medium',
    ComplaintSeverity.high => 'High',
  };

  SemanticTone get tone => switch (this) {
    ComplaintSeverity.low => SemanticTone.success,
    ComplaintSeverity.medium => SemanticTone.warning,
    ComplaintSeverity.high => SemanticTone.danger,
  };
}
