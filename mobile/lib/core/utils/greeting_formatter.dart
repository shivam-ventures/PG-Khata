import '../../l10n/app_localizations.dart';

/// The "Good morning/afternoon/evening, {name}" greeting used on the Owner
/// and Manager home screens.
abstract final class GreetingFormatter {
  static String timeOfDay({DateTime? at}) {
    final hour = (at ?? DateTime.now()).hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  /// Unlocalized — kept only for call sites not yet migrated. Prefer
  /// [greetingFor].
  static String greeting(String firstName, {DateTime? at}) =>
      'Good ${timeOfDay(at: at)}, $firstName';

  static String greetingFor(
    AppLocalizations l10n,
    String firstName, {
    DateTime? at,
  }) => switch (timeOfDay(at: at)) {
    'morning' => l10n.greetingMorning(firstName),
    'afternoon' => l10n.greetingAfternoon(firstName),
    _ => l10n.greetingEvening(firstName),
  };
}
