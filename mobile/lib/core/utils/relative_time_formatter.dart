/// Formats how long ago a moment was, the way the Complaints screens show
/// it (`Tenant Complaints.dc.html`'s "Reported 2 days ago", `Manager
/// Complaints.dc.html`'s "2 days open") — computed live off the stored
/// timestamp rather than a string baked in at creation time, so it stays
/// accurate as real time passes.
abstract final class RelativeTimeFormatter {
  static String _unitCount(Duration diff) {
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'}';
    }
    if (diff.inDays < 1) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'}';
    }
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'}';
  }

  /// e.g. "Reported 2 days ago" → pass the timestamp, get "2 days ago".
  static String ago(DateTime time) {
    final unit = _unitCount(DateTime.now().difference(time));
    if (unit == 'just now') return unit;
    return unit == '1 day' ? 'yesterday' : '$unit ago';
  }

  /// e.g. "2 days open" — used for a still-open item's age instead of "ago".
  static String open(DateTime time) {
    final unit = _unitCount(DateTime.now().difference(time));
    return unit == 'just now' ? unit : '$unit open';
  }
}
