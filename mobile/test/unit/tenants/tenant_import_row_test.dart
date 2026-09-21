import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/utils/csv_parser.dart';
import 'package:pg_khata/features/tenants/domain/tenant_import_row.dart';

void main() {
  test('parses a valid row end to end from raw CSV', () {
    const csv = 'Name,Phone,Room/Bed,Rent\n'
        'Amit Verma,9845123456,101 - C,6500\n';
    final row = parseTenantRow(parseCsvRows(csv).single);
    expect(row.isValid, isTrue);
    expect(row.name, 'Amit Verma');
    expect(row.roomBed, '101 - C');
    expect(row.rent, 6500);
  });

  test('phone is optional', () {
    final row = parseTenantRow({
      'Name': 'Sneha Reddy',
      'Phone': '',
      'Room/Bed': '102 - A',
      'Rent': '7500',
    });
    expect(row.isValid, isTrue);
    expect(row.phone, isEmpty);
  });

  test('flags a missing room/bed', () {
    final row = parseTenantRow({
      'Name': 'Rohit Malhotra',
      'Phone': '9812345678',
      'Room/Bed': '',
      'Rent': '6500',
    });
    expect(row.isValid, isFalse);
    expect(row.error, 'Missing room/bed');
  });

  test('flags a zero or negative rent', () {
    final row = parseTenantRow({
      'Name': 'Priya Nair',
      'Room/Bed': '201 - B',
      'Rent': '0',
    });
    expect(row.isValid, isFalse);
    expect(row.error, 'Invalid rent');
  });
}
