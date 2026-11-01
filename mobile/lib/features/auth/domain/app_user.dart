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
    this.preferredLanguage = 'en',
    this.notifyComplaints = true,
    this.notifyAnnouncements = true,
  });

  final String id;
  final String name;
  final String phone;
  final UserRole role;

  /// ISO 639-1 — only 'en'/'te' are real translations right now (see
  /// `lib/l10n`).
  final String preferredLanguage;
  final bool notifyComplaints;
  final bool notifyAnnouncements;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          phone == other.phone &&
          role == other.role &&
          preferredLanguage == other.preferredLanguage &&
          notifyComplaints == other.notifyComplaints &&
          notifyAnnouncements == other.notifyAnnouncements;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    role,
    preferredLanguage,
    notifyComplaints,
    notifyAnnouncements,
  );
}
