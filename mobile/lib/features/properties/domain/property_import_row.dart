import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';

/// Why a bulk-import CSV row failed validation.
enum PropertyImportRowError {
  missingName,
  missingAddress,
  invalidTotalBeds,
  missingManagerName;

  String labelFor(AppLocalizations l10n) => switch (this) {
    PropertyImportRowError.missingName => l10n.propertyImportErrorMissingName,
    PropertyImportRowError.missingAddress =>
      l10n.propertyImportErrorMissingAddress,
    PropertyImportRowError.invalidTotalBeds =>
      l10n.propertyImportErrorInvalidTotalBeds,
    PropertyImportRowError.missingManagerName =>
      l10n.propertyImportErrorMissingManagerName,
  };
}

/// One row parsed from a bulk-import CSV, validated against what
/// [PropertiesController.addProperty] needs.
@immutable
class ParsedPropertyRow {
  const ParsedPropertyRow({
    required this.name,
    required this.address,
    required this.totalBeds,
    required this.managerName,
    this.error,
  });

  final String name;
  final String address;
  final int? totalBeds;
  final String managerName;
  final PropertyImportRowError? error;

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
/// [ParsedPropertyRow], flagging the first missing/invalid required field.
ParsedPropertyRow parsePropertyRow(Map<String, String> row) {
  final name = _field(row, ['name', 'property name']);
  final address = _field(row, ['address']);
  final bedsText = _field(row, ['total beds', 'beds']);
  final managerName = _field(row, ['manager name', 'manager']);
  final beds = int.tryParse(bedsText);

  PropertyImportRowError? error;
  if (name.isEmpty) {
    error = PropertyImportRowError.missingName;
  } else if (address.isEmpty) {
    error = PropertyImportRowError.missingAddress;
  } else if (beds == null || beds <= 0) {
    error = PropertyImportRowError.invalidTotalBeds;
  } else if (managerName.isEmpty) {
    error = PropertyImportRowError.missingManagerName;
  }

  return ParsedPropertyRow(
    name: name,
    address: address,
    totalBeds: beds,
    managerName: managerName,
    error: error,
  );
}
