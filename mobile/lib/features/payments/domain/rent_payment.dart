import 'package:flutter/foundation.dart';

import 'payment_method.dart';
import 'payment_status.dart';

/// One tenant's rent for one monthly period. Mirrors `docs/domain-model-notes.md`'s
/// Payment entity — a frontend/domain model, not the eventual Supabase row shape.
@immutable
class RentPayment {
  const RentPayment({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.propertyId,
    required this.propertyName,
    required this.room,
    required this.amount,
    int? expectedAmount,
    required this.periodMonth,
    required this.dueDate,
    required this.status,
    this.method,
    this.paidDate,
  }) : expectedAmount = expectedAmount ?? amount;

  final String id;
  final String tenantId;
  final String tenantName;
  final String propertyId;
  final String propertyName;
  final String room;

  /// The amount actually recorded for this period — equal to
  /// [expectedAmount] until someone records a payment, at which point it's
  /// whatever they entered (which may legitimately differ, e.g. a partial
  /// or adjusted payment).
  final int amount;

  /// The tenant's on-record rent for this period, independent of whatever
  /// gets typed into a Collect/Record dialog. [voidPayment] restores
  /// [amount] to this value; the dialogs compare against it to warn when a
  /// typed amount doesn't match what's actually owed.
  final int expectedAmount;

  /// The first-of-month marker for the rent cycle this row covers, e.g.
  /// `DateTime(2026, 9)` for September 2026 — distinct from [dueDate], which
  /// is the day rent is due within that cycle.
  final DateTime periodMonth;
  final DateTime dueDate;
  final PaymentStatus status;

  /// Null until a payment is recorded (still pending/overdue).
  final PaymentMethod? method;

  /// When the payment was recorded — set once [method] is set, regardless
  /// of whether a cash payment is still awaiting the tenant's confirmation.
  final DateTime? paidDate;

  RentPayment copyWith({
    PaymentStatus? status,
    PaymentMethod? method,
    DateTime? paidDate,
    int? amount,
    bool clearMethodAndPaidDate = false,
  }) {
    return RentPayment(
      id: id,
      tenantId: tenantId,
      tenantName: tenantName,
      propertyId: propertyId,
      propertyName: propertyName,
      room: room,
      amount: amount ?? this.amount,
      expectedAmount: expectedAmount,
      periodMonth: periodMonth,
      dueDate: dueDate,
      status: status ?? this.status,
      method: clearMethodAndPaidDate ? null : (method ?? this.method),
      paidDate: clearMethodAndPaidDate ? null : (paidDate ?? this.paidDate),
    );
  }
}
