/// A tenant's preferred time-of-day for a fix, per `Tenant Complaints.dc.html`'s
/// "Preferred time to fix" dropdown.
enum TimePreference {
  anytime,
  morning,
  afternoon,
  evening;

  String get label => switch (this) {
    TimePreference.anytime => 'Anytime',
    TimePreference.morning => 'Morning (8am–12pm)',
    TimePreference.afternoon => 'Afternoon (12–4pm)',
    TimePreference.evening => 'Evening (4–8pm)',
  };
}
