import 'package:flutter/foundation.dart';

/// An Owner's PG. Mirrors `docs/domain-model-notes.md`'s Property entity —
/// a frontend/domain model, not the eventual Supabase row shape.
///
/// [totalBeds] here is the capacity an Owner declares when adding the PG,
/// before any rooms exist to count. Occupancy, rent and open-complaint
/// figures are *not* stored on Property — they're computed live from
/// Rooms/Payments/Complaints by `propertyMetricsProvider`, so they can
/// never drift from what those screens themselves show.
@immutable
class Property {
  const Property({
    required this.id,
    required this.name,
    required this.address,
    required this.totalBeds,
    required this.managerName,
    this.managerId,
  });

  final String id;
  final String name;
  final String address;
  final int totalBeds;
  final String managerName;

  /// Null when [managerName] is 'Unassigned' (or, for a mock/test Property,
  /// simply never set) — the real id behind the display name, needed to
  /// pre-select the current manager in the Add/Edit PG dialog's picker
  /// without re-resolving it by name.
  final String? managerId;

  Property copyWith({
    String? name,
    String? address,
    int? totalBeds,
    String? managerName,
  }) {
    return Property(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      totalBeds: totalBeds ?? this.totalBeds,
      managerName: managerName ?? this.managerName,
      managerId: managerId,
    );
  }
}
