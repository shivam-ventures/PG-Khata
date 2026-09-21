import 'package:flutter/foundation.dart';

/// One row parsed from a bulk-import CSV, validated against what
/// the top-level `addTenant` function needs.
@immutable
class ParsedTenantRow {
  const ParsedTenantRow({
    required this.name,
    required this.phone,
    required this.roomBed,
    required this.rent,
    this.error,
  });

  final String name;
  final String phone;
  final String roomBed;
  final int? rent;
  final String? error;

  bool get isValid => error == null;
}

String _field(Map<String, String> row, List<String> keys) {
  for (final key in keys) {
    final match = row.entries.firstWhere(
      (e) => e.key.toLowerCase() == key,
      orElse: () => const MapEntry('', ''),
    );
    if (match.value.isNotEmpty) return match.value;
  }
  return '';
}

/// Maps one CSV row (keyed by header name, case-insensitive) to a
/// [ParsedTenantRow], flagging the first missing/invalid required field.
ParsedTenantRow parseTenantRow(Map<String, String> row) {
  final name = _field(row, ['name', 'full name']);
  final phone = _field(row, ['phone', 'phone number']);
  final roomBed = _field(row, ['room/bed', 'room / bed', 'room', 'bed']);
  final rentText = _field(row, ['rent', 'monthly rent']);
  final rent = int.tryParse(rentText);

  String? error;
  if (name.isEmpty) {
    error = 'Missing name';
  } else if (roomBed.isEmpty) {
    error = 'Missing room/bed';
  } else if (rent == null || rent <= 0) {
    error = 'Invalid rent';
  }

  return ParsedTenantRow(
    name: name,
    phone: phone,
    roomBed: roomBed,
    rent: rent,
    error: error,
  );
}
