import 'package:flutter/foundation.dart';

/// An Owner's PG. Mirrors `docs/domain-model-notes.md`'s Property entity —
/// a frontend/domain model, not the eventual Supabase row shape.
@immutable
class Property {
  const Property({
    required this.id,
    required this.name,
    required this.address,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.rentCollected,
    required this.rentExpected,
    required this.openComplaints,
    required this.managerName,
  });

  final String id;
  final String name;
  final String address;
  final int totalBeds;
  final int occupiedBeds;
  final int rentCollected;
  final int rentExpected;
  final int openComplaints;
  final String managerName;

  double get occupancyFraction => totalBeds == 0 ? 0 : occupiedBeds / totalBeds;

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
      occupiedBeds: occupiedBeds,
      rentCollected: rentCollected,
      rentExpected: rentExpected,
      openComplaints: openComplaints,
      managerName: managerName ?? this.managerName,
    );
  }
}
