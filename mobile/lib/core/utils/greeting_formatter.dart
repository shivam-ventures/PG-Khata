/// The "Good morning/afternoon/evening, {name}" greeting used on the Owner
/// and Manager home screens.
abstract final class GreetingFormatter {
  static String timeOfDay({DateTime? at}) {
    final hour = (at ?? DateTime.now()).hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  static String greeting(String firstName, {DateTime? at}) =>
      'Good ${timeOfDay(at: at)}, $firstName';
}
