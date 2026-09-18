/// Formats whole-rupee amounts the way the approved design does: plain
/// Indian digit grouping under ₹1 lakh (`₹8,500`), a lakh/crore shorthand
/// above it (`₹4.1L`) — see the Owner Dashboard's "Rent collected" stat.
abstract final class CurrencyFormatter {
  static const _lakh = 100000;
  static const _crore = 10000000;

  /// e.g. `250 -> ₹250`, `8500 -> ₹8,500`, `410000 -> ₹4.1L`, `12500000 -> ₹1.25Cr`.
  static String rupees(num amount) {
    final rounded = amount.round();
    if (rounded.abs() >= _crore) {
      return '₹${_shorthand(rounded / _crore)}Cr';
    }
    if (rounded.abs() >= _lakh) {
      return '₹${_shorthand(rounded / _lakh)}L';
    }
    return '₹${_groupIndian(rounded.abs().toString())}';
  }

  static String _shorthand(double value) {
    final text = value.toStringAsFixed(2);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String _groupIndian(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$last3';
  }
}
