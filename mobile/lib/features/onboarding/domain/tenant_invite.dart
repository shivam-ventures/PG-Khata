import 'package:flutter/foundation.dart';

/// A bed-specific invite, resolved from the token in a `/join/:token` link.
/// Mirrors `Auth.dc.html`'s `hasInvite` branch. Backed by a real persisted,
/// expiring `tenant_invite_links` row (`docs/backend-domain-model.md`
/// §12.4) — the token is an opaque random string, not a derived
/// `propertyId-room-bed` composite the way the Phase-1 mock built it.
@immutable
class TenantInvite {
  const TenantInvite({
    required this.token,
    required this.propertyName,
    required this.room,
    required this.bed,
    required this.rentPerBed,
    required this.managerName,
  });

  final String token;
  final String propertyName;
  final String room;
  final String bed;
  final int rentPerBed;
  final String managerName;
}
