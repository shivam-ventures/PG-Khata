import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/semantic_tone.dart';

/// The category a tenant picks when reporting an issue. Matches the
/// category tiles on `Tenant Complaints.dc.html`'s report dialog.
enum ComplaintCategory {
  plumbing,
  electrical,
  wifi,
  cleaning,
  other;

  /// Unlocalized — kept only for call sites not yet migrated. Prefer
  /// [labelFor].
  String get label => switch (this) {
    ComplaintCategory.plumbing => 'Plumbing',
    ComplaintCategory.electrical => 'Electrical',
    ComplaintCategory.wifi => 'Wifi/Internet',
    ComplaintCategory.cleaning => 'Cleaning',
    ComplaintCategory.other => 'Other',
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    ComplaintCategory.plumbing => l10n.complaintCategoryPlumbing,
    ComplaintCategory.electrical => l10n.complaintCategoryElectrical,
    ComplaintCategory.wifi => l10n.complaintCategoryWifi,
    ComplaintCategory.cleaning => l10n.complaintCategoryCleaning,
    ComplaintCategory.other => l10n.complaintCategoryOther,
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
