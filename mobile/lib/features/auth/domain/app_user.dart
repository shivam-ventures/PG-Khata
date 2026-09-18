import 'package:flutter/foundation.dart';

import 'user_role.dart';

/// The signed-in person. Mirrors the `profiles` shape from
/// `docs/domain-model-notes.md`, trimmed to what the UI needs in Phase 0 —
/// this is a frontend/domain model, not the eventual Supabase row shape.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  final String id;
  final String name;
  final String phone;
  final UserRole role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          phone == other.phone &&
          role == other.role;

  @override
  int get hashCode => Object.hash(id, name, phone, role);
}
