import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/utils/csv_parser.dart';

void main() {
  test('parses a header row plus data rows into maps', () {
    const csv = 'Name,Address,Total Beds,Manager Name\n'
        'HSR PG,27th Main HSR,20,Ramesh K.\n'
        'Koramangala PG,5th Block Koramangala,18,Divya S.\n';
    final rows = parseCsvRows(csv);
    expect(rows.length, 2);
    expect(rows[0]['Name'], 'HSR PG');
    expect(rows[0]['Total Beds'], '20');
    expect(rows[1]['Manager Name'], 'Divya S.');
  });

  test('handles a quoted field containing a comma', () {
    const csv = 'Name,Address\n"HSR PG","27th Main, HSR Layout"\n';
    final rows = parseCsvRows(csv);
    expect(rows.single['Address'], '27th Main, HSR Layout');
  });

  test('skips blank trailing lines', () {
    const csv = 'Name,Rent\nRahul,8500\n\n';
    final rows = parseCsvRows(csv);
    expect(rows.length, 1);
  });

  test('returns an empty list for a header-only file', () {
    const csv = 'Name,Address,Total Beds,Manager Name\n';
    expect(parseCsvRows(csv), isEmpty);
  });
}
