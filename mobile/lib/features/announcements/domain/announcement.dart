import 'package:flutter/foundation.dart';

/// A broadcast an Owner/Manager posted to one property's current tenants.
/// Mirrors `Tenant Home.dc.html`'s announcement banner — the display slot
/// existed since Phase 0 with nothing to feed it; this is the real thing.
@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.body,
    required this.createdByName,
    required this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String propertyId;
  final String title;
  final String body;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? expiresAt;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
}
