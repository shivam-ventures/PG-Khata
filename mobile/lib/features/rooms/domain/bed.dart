import 'package:flutter/foundation.dart';

/// One bed in a room — vacant, or occupied by a named tenant. Mirrors
/// `docs/domain-model-notes.md`'s Bed entity.
@immutable
class Bed {
  const Bed({required this.label, this.tenantName});

  final String label;
  final String? tenantName;

  bool get isVacant => tenantName == null;
}
