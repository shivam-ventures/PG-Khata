import '../../../l10n/app_localizations.dart';

/// A tenant's preferred time-of-day for a fix, per `Tenant Complaints.dc.html`'s
/// "Preferred time to fix" dropdown.
enum TimePreference {
  anytime,
  morning,
  afternoon,
  evening;

  /// Unlocalized — kept only for call sites not yet migrated. Prefer
  /// [labelFor].
  String get label => switch (this) {
    TimePreference.anytime => 'Anytime',
    TimePreference.morning => 'Morning (8am–12pm)',
    TimePreference.afternoon => 'Afternoon (12–4pm)',
    TimePreference.evening => 'Evening (4–8pm)',
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    TimePreference.anytime => l10n.timePreferenceAnytime,
    TimePreference.morning => l10n.timePreferenceMorning,
    TimePreference.afternoon => l10n.timePreferenceAfternoon,
    TimePreference.evening => l10n.timePreferenceEvening,
  };
}
