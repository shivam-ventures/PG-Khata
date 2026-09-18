/// Formats a date the way the approved design's screen headers do, e.g.
/// "Wednesday, 16 September" — today's actual date, not data from a
/// repository, so this stays a device-clock utility rather than a domain field.
abstract final class DateLabelFormatter {
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday', //
  ];

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String format(DateTime date) {
    final weekday = _weekdays[date.weekday - 1];
    final month = _months[date.month - 1];
    return '$weekday, ${date.day} $month';
  }

  static String today() => format(DateTime.now());
}
