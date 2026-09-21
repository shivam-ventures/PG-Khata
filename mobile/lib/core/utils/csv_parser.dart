import 'package:csv/csv.dart';

/// Parses a CSV file's contents into row maps keyed by its header row —
/// used by the bulk-import flows (Owner Properties, Manager Tenants) to
/// turn an uploaded spreadsheet into structured data without hand-rolling
/// comma-splitting (which breaks on quoted fields containing commas).
List<Map<String, String>> parseCsvRows(String csvString) {
  final table = Csv().decode(csvString);
  if (table.length < 2) return [];

  final headers = table.first.map((cell) => cell.toString().trim()).toList();
  return [
    for (final row in table.skip(1))
      if (row.any((cell) => cell.toString().trim().isNotEmpty))
        {
          for (var i = 0; i < headers.length; i++)
            headers[i]: i < row.length ? row[i].toString().trim() : '',
        },
  ];
}
