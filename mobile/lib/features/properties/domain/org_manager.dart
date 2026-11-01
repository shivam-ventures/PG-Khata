import 'package:flutter/foundation.dart';

/// A Manager account already active somewhere in the Owner's org — the
/// pool to pick from when assigning a manager to a property, instead of
/// creating a duplicate account for someone who already has one.
@immutable
class OrgManager {
  const OrgManager({required this.id, required this.name, required this.phone});

  final String id;
  final String name;
  final String phone;
}
