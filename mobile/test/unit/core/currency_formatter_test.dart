import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.rupees', () {
    test('formats zero', () {
      expect(CurrencyFormatter.rupees(0), '₹0');
    });

    test('formats small amounts with Indian grouping', () {
      expect(CurrencyFormatter.rupees(250), '₹250');
      expect(CurrencyFormatter.rupees(8500), '₹8,500');
      expect(CurrencyFormatter.rupees(32000), '₹32,000');
    });

    test('groups a 5-digit amount in the Indian 2-3 pattern', () {
      expect(CurrencyFormatter.rupees(87654), '₹87,654');
    });

    test('formats amounts at and above 1 lakh with the L shorthand', () {
      expect(CurrencyFormatter.rupees(100000), '₹1L');
      expect(CurrencyFormatter.rupees(410000), '₹4.1L');
      expect(CurrencyFormatter.rupees(460000), '₹4.6L');
    });

    test('formats amounts at and above 1 crore with the Cr shorthand', () {
      expect(CurrencyFormatter.rupees(10000000), '₹1Cr');
      expect(CurrencyFormatter.rupees(12500000), '₹1.25Cr');
    });
  });
}
