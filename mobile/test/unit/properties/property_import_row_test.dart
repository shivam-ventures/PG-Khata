import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/utils/csv_parser.dart';
import 'package:pg_khata/features/properties/domain/property_import_row.dart';

void main() {
  test('parses a valid row end to end from raw CSV', () {
    const csv = 'Name,Address,Total Beds,Manager Name\n'
        'Whitefield PG,ITPL Road Whitefield,15,Suresh M.\n';
    final row = parsePropertyRow(parseCsvRows(csv).single);
    expect(row.isValid, isTrue);
    expect(row.name, 'Whitefield PG');
    expect(row.totalBeds, 15);
    expect(row.managerName, 'Suresh M.');
  });

  test('flags a missing manager name', () {
    final row = parsePropertyRow({
      'Name': 'Electronic City PG',
      'Address': 'Neeladri Road',
      'Total Beds': '10',
      'Manager Name': '',
    });
    expect(row.isValid, isFalse);
    expect(row.error, 'Missing manager name');
  });

  test('flags a non-numeric bed count', () {
    final row = parsePropertyRow({
      'Name': 'BadRow PG',
      'Address': 'No beds here',
      'Total Beds': 'notanumber',
      'Manager Name': 'Someone',
    });
    expect(row.isValid, isFalse);
    expect(row.error, 'Invalid total beds');
  });

  test('matches header names case-insensitively', () {
    final row = parsePropertyRow({
      'name': 'HSR PG',
      'address': '27th Main',
      'total beds': '20',
      'manager name': 'Ramesh K.',
    });
    expect(row.isValid, isTrue);
  });
}
