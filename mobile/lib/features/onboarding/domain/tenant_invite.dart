import 'package:flutter/foundation.dart';

/// A bed-specific invite, resolved from the token in a `/join/:token` link.
/// Mirrors `Auth.dc.html`'s `hasInvite` branch and the URL shape Manager
/// Rooms' "Invite via link" dialog already builds
/// (`propertyId-room-bed`) — see `docs/domain-model-notes.md`'s open
/// question on whether this ever needs to be a persisted, expiring entity
/// rather than derived on demand, as it is here.
@immutable
class TenantInvite {
  const TenantInvite({
    required this.token,
    required this.propertyId,
    required this.propertyName,
    required this.room,
    required this.bed,
    required this.rentPerBed,
    required this.managerName,
  });

  final String token;
  final String propertyId;
  final String propertyName;
  final String room;
  final String bed;
  final int rentPerBed;
  final String managerName;
}
