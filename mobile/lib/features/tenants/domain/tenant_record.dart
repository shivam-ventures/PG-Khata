import 'package:flutter/foundation.dart';

import 'tenant_status.dart';

/// A tenant assigned to a bed. Mirrors `docs/domain-model-notes.md`'s
/// Tenant entity — a frontend/domain model, not the eventual Supabase row
/// shape (which splits identity from tenancy; not needed for mock data).
@immutable
class TenantRecord {
  const TenantRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.propertyId,
    required this.propertyName,
    required this.roomBed,
    required this.rent,
    required this.joinedDate,
    required this.status,
    this.depositAmount,
  });

  final String id;
  final String name;
  final String phone;
  final String propertyId;
  final String propertyName;
  final String roomBed;
  final int rent;
  final DateTime joinedDate;
  final TenantStatus status;

  /// The refundable security deposit collected at move-in, if any — not
  /// every PG charges one, and the ones that do vary by amount, so this
  /// stays optional rather than derived from rent.
  final int? depositAmount;

  bool get canMoveOut =>
      status == TenantStatus.active || status == TenantStatus.noticePeriod;

  TenantRecord copyWith({
    String? name,
    String? roomBed,
    int? rent,
    DateTime? joinedDate,
    TenantStatus? status,
    int? depositAmount,
  }) {
    return TenantRecord(
      id: id,
      name: name ?? this.name,
      phone: phone,
      propertyId: propertyId,
      propertyName: propertyName,
      roomBed: roomBed ?? this.roomBed,
      rent: rent ?? this.rent,
      joinedDate: joinedDate ?? this.joinedDate,
      status: status ?? this.status,
      depositAmount: depositAmount ?? this.depositAmount,
    );
  }
}

/// A self-registered person waiting for staff to assign them a bed. The
/// tenant-*requested* self-registration flow itself is explicitly not
/// adopted yet (`docs/design-readme-reconciliation.md` §6.3) — these
/// records exist only as seeded mock data showing what the assign step
/// looks like once that flow lands.
@immutable
class PendingTenant {
  const PendingTenant({
    required this.id,
    required this.name,
    required this.phone,
    required this.propertyId,
    required this.propertyName,
  });

  final String id;
  final String name;
  final String phone;
  final String propertyId;
  final String propertyName;
}
