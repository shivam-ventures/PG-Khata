import 'package:flutter/material.dart';

import '../../../shared/widgets/semantic_tone.dart';

/// The category a tenant picks when reporting an issue. Matches the
/// category tiles on `Tenant Complaints.dc.html`'s report dialog.
enum ComplaintCategory {
  plumbing,
  electrical,
  wifi,
  cleaning,
  other;

  String get label => switch (this) {
    ComplaintCategory.plumbing => 'Plumbing',
    ComplaintCategory.electrical => 'Electrical',
    ComplaintCategory.wifi => 'Wifi/Internet',
    ComplaintCategory.cleaning => 'Cleaning',
    ComplaintCategory.other => 'Other',
  };

  IconData get icon => switch (this) {
    ComplaintCategory.plumbing => Icons.water_drop_outlined,
    ComplaintCategory.electrical => Icons.bolt_outlined,
    ComplaintCategory.wifi => Icons.wifi,
    ComplaintCategory.cleaning => Icons.cleaning_services_outlined,
    ComplaintCategory.other => Icons.more_horiz,
  };

  SemanticTone get tone => switch (this) {
    ComplaintCategory.plumbing => SemanticTone.info,
    ComplaintCategory.electrical => SemanticTone.warning,
    ComplaintCategory.wifi => SemanticTone.accent,
    ComplaintCategory.cleaning => SemanticTone.success,
    ComplaintCategory.other => SemanticTone.neutral,
  };
}
