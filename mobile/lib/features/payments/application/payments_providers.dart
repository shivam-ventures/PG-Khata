import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/payments_repository.dart';
import '../data/supabase_payments_repository.dart';
import '../domain/payment_method.dart';
import '../domain/rent_payment.dart';

/// The single override point for swapping the payments data source — was
/// `MockPaymentsRepository()` through Phase 3; now backed by real Supabase
/// rent periods/payments and RPCs.
final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => SupabasePaymentsRepository(ref.watch(supabaseClientProvider)),
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
///
/// [idempotencyKey]: generate this ONCE per submit attempt at the call site
/// (e.g. a `late final` field on the dialog's state, created when the
/// dialog opens) and pass the SAME value again on any retry of that same
/// attempt — never a fresh one per network call. That's what lets a
/// double-tap or a retry-after-timeout land on the same payment server-side
/// instead of recording it twice.
Future<AppFailure?> recordPayment(
  WidgetRef ref,
  String paymentId, {
  required PaymentMethod method,
  required int amount,
  required DateTime date,
  String? idempotencyKey,
}) async {
  final result = await ref
      .read(paymentsRepositoryProvider)
      .recordPayment(
        paymentId,
        method: method,
        amount: amount,
        date: date,
        idempotencyKey: idempotencyKey,
      );
  return result.when(
    ok: (_) {
      _invalidatePayments(ref);
      return null;
    },
    err: (failure) => failure,
  );
}

/// The tenant paying their own rent through the app — settles instantly.
/// See [recordPayment] for [idempotencyKey].
Future<AppFailure?> recordSelfPayment(
  WidgetRef ref,
  String paymentId, {
  required PaymentMethod method,
  required int amount,
  required DateTime date,
  String? idempotencyKey,
}) async {
  final result = await ref
      .read(paymentsRepositoryProvider)
      .recordSelfPayment(
        paymentId,
        method: method,
        amount: amount,
        date: date,
        idempotencyKey: idempotencyKey,
      );
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

/// Owner-only close-out of a disputed payment — see
/// `PaymentsRepository.resolveDispute`.
Future<AppFailure?> resolveDispute(
  WidgetRef ref,
  String paymentId, {
  required bool paid,
  required String note,
}) async {
  final result = await ref
      .read(paymentsRepositoryProvider)
      .resolveDispute(paymentId, paid: paid, note: note);
  return result.when(
    ok: (_) {
      _invalidatePayments(ref);
      return null;
    },
    err: (failure) => failure,
  );
}
