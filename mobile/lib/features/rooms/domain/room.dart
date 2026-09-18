import 'package:flutter/foundation.dart';

import 'bed.dart';
import 'sharing_type.dart';

/// A room within a property, grouped by a free-text floor label per
/// `docs/domain-model-notes.md` (no separate "Building"/"Floor" entity —
/// matches the design exactly).
@immutable
class Room {
  const Room({
    required this.number,
    required this.floor,
    required this.sharingType,
    required this.rentPerBed,
    required this.beds,
  });

  final String number;
  final String floor;
  final SharingType sharingType;
  final int rentPerBed;
  final List<Bed> beds;

  bool get hasVacantBed => beds.any((bed) => bed.isVacant);
}

/// A floor grouping within a property's room list — Owner Rooms groups by
/// this; Manager Rooms shows a flat list (matching each screen's design).
@immutable
class Floor {
  const Floor({required this.name, required this.rooms});

  final String name;
  final List<Room> rooms;
}
