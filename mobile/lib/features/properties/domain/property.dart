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
  });

  final String id;
  final String name;
  final String address;
  final int totalBeds;
  final String managerName;

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
    );
  }
}
