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

  static const _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec',
  ];

  /// A due/paid-date label the way the payments screens show it, e.g. "28 Sept".
  static String short(DateTime date) => '${date.day} ${_shortMonths[date.month - 1]}';

  /// A rent-period label, e.g. "September 2026" — see the Tenant Payments
  /// history list.
  static String monthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';
}
