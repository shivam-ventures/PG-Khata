import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../data/mock_payments_repository.dart';
import '../data/payments_repository.dart';
import '../domain/payment_method.dart';
import '../domain/rent_payment.dart';

/// The single override point for swapping the payments data source: point
/// this at a Supabase-backed implementation in Phase 6.
final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => MockPaymentsRepository(),
);

/// Each tenant's current-period payment for a property (`null` = every
/// property, for the Owner's portfolio-wide ledger).
final latestPaymentsProvider =
    FutureProvider.family<List<RentPayment>, String?>((ref, propertyId) async {
      final result = await ref
          .watch(paymentsRepositoryProvider)
          .fetchLatestPayments(propertyId: propertyId);
      return result.when(ok: (v) => v, err: (failure) => throw failure);
    });

/// A single tenant's full rent history, newest period first.
final paymentHistoryProvider = FutureProvider.family<List<RentPayment>, String>(
  (ref, tenantId) async {
    final result = await ref
        .watch(paymentsRepositoryProvider)
        .fetchPaymentHistory(tenantId);
    return result.when(ok: (v) => v, err: (failure) => throw failure);
  },
);

void _invalidatePayments(WidgetRef ref) {
  ref.invalidate(latestPaymentsProvider);
  ref.invalidate(paymentHistoryProvider);
}

/// A Manager/Owner recording a payment on a tenant's behalf — always lands
/// on awaiting-confirmation. See `PaymentsRepository.recordPayment`'s doc
/// comment.
Future<AppFailure?> recordPayment(
  WidgetRef ref,
  String paymentId, {
  required PaymentMethod method,
  required int amount,
  required DateTime date,
}) async {
  final result = await ref
      .read(paymentsRepositoryProvider)
      .recordPayment(paymentId, method: method, amount: amount, date: date);
  return result.when(
    ok: (_) {
      _invalidatePayments(ref);
      return null;
    },
    err: (failure) => failure,
  );
}

/// The tenant paying their own rent through the app — settles instantly.
Future<AppFailure?> recordSelfPayment(
  WidgetRef ref,
  String paymentId, {
  required PaymentMethod method,
  required int amount,
  required DateTime date,
}) async {
  final result = await ref
      .read(paymentsRepositoryProvider)
      .recordSelfPayment(paymentId, method: method, amount: amount, date: date);
  return result.when(
    ok: (_) {
      _invalidatePayments(ref);
      return null;
    },
    err: (failure) => failure,
  );
}

Future<AppFailure?> confirmPayment(WidgetRef ref, String paymentId) async {
  final result = await ref
      .read(paymentsRepositoryProvider)
      .confirmPayment(paymentId);
  return result.when(
    ok: (_) {
      _invalidatePayments(ref);
      return null;
    },
    err: (failure) => failure,
  );
}

Future<AppFailure?> disputePayment(WidgetRef ref, String paymentId) async {
  final result = await ref
      .read(paymentsRepositoryProvider)
      .disputePayment(paymentId);
  return result.when(
    ok: (_) {
      _invalidatePayments(ref);
      return null;
    },
    err: (failure) => failure,
  );
}

/// Undoes a mistaken entry — see `PaymentsRepository.voidPayment`.
Future<AppFailure?> voidPayment(WidgetRef ref, String paymentId) async {
  final result = await ref.read(paymentsRepositoryProvider).voidPayment(paymentId);
  return result.when(
    ok: (_) {
      _invalidatePayments(ref);
      return null;
    },
    err: (failure) => failure,
  );
}
