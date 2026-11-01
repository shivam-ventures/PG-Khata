import 'package:flutter/foundation.dart';

import 'deposit_settlement.dart';
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
    this.moveOutDate,
    this.noticeGivenAt,
    this.depositSettlement,
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

  /// Set once notice is given ([TenantStatus.noticePeriod]) or once moved
  /// out — the planned date while in notice, the actual date afterward
  /// (they're always the same by construction: finalizing a notice never
  /// changes the date, it only flips the status).
  final DateTime? moveOutDate;

  /// When notice was recorded — `null` for a tenancy that's never had one
  /// (including a direct, zero-notice move-out, which never goes through
  /// [TenantStatus.noticePeriod] at all).
  final DateTime? noticeGivenAt;

  final DepositSettlement? depositSettlement;

  /// The immediate, no-notice action — always available while the tenancy
  /// hasn't already ended, same as before this had a notice period at all.
  bool get canMoveOut =>
      status == TenantStatus.active || status == TenantStatus.noticePeriod;

  bool get canGiveNotice => status == TenantStatus.active;

  bool get canCancelNotice => status == TenantStatus.noticePeriod;

  /// Staff can confirm a pending deposit was actually handed back once
  /// there's something to settle — regardless of how it got resolved,
  /// matching the backend's own "professional judgment override" allowance.
  bool get canMarkDepositReturned =>
      depositSettlement != null && depositSettlement != DepositSettlement.returned;

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
      moveOutDate: moveOutDate,
      noticeGivenAt: noticeGivenAt,
      depositSettlement: depositSettlement,
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
