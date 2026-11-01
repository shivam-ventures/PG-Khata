import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/payment_method.dart';
import '../domain/payment_status.dart';
import '../domain/rent_payment.dart';
import 'payments_repository.dart';

/// Real backend for [PaymentsRepository]. The read model is
/// `rent_period_status`, a view deriving each period's current status live
/// from its latest non-voided payment attempt (`docs/backend-domain-model.md`
/// §7) — [RentPayment.id] is always a `rent_period_id`, stable across
/// however many payment attempts a period goes through, matching the
/// mock's "one row per period" shape.
///
/// `confirm`/`dispute`/`void` operate on the underlying *payment* row, not
/// the period, so each looks up `latest_payment_id` first. `record`/
/// `recordSelf` accept [DateTime date] for interface compatibility with the
/// mock's date-picker dialogs, but never use it — `payments.paid_at`
/// always defaults to when the write actually happens; the real schema has
/// no way to backdate a payment.
class SupabasePaymentsRepository implements PaymentsRepository {
  SupabasePaymentsRepository(this._client);

  final SupabaseClient _client;

  static const _tenancySelectColumns =
      'id, beds!inner(label, rooms!inner(room_number, property_id, '
      'properties!inner(id, name))), '
      'tenant:profiles!tenancies_profile_id_fkey(full_name, phone)';

  @override
  Future<Result<List<RentPayment>>> fetchLatestPayments({
    String? propertyId,
  }) async {
    // A blank id shows up briefly for a Manager whose real assigned
    // property hasn't loaded yet (see managerSelectedPgIdProvider) —
    // nothing can match it, so skip the fetch+join entirely.
    if (propertyId == '') return const Ok([]);
    try {
      final periodRows = await _client.from('rent_period_status').select();
      final latestByTenancy = <String, Map<String, dynamic>>{};
      for (final row in periodRows) {
        final tenancyId = row['tenancy_id'] as String;
        final current = latestByTenancy[tenancyId];
        if (current == null ||
            DateTime.parse(
              row['period_month'] as String,
            ).isAfter(DateTime.parse(current['period_month'] as String))) {
          latestByTenancy[tenancyId] = row;
        }
      }
      final tenancies = await _tenanciesById(latestByTenancy.keys);
      final payments = <RentPayment>[];
      for (final entry in latestByTenancy.entries) {
        final tenancy = tenancies[entry.key];
        if (tenancy == null) continue;
        final payment = _toRentPayment(entry.value, tenancy);
        if (propertyId == null || payment.propertyId == propertyId) {
          payments.add(payment);
        }
      }
      return Ok(payments);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<List<RentPayment>>> fetchPaymentHistory(
    String tenantId,
  ) async {
    try {
      final periodRows = await _client
          .from('rent_period_status')
          .select()
          .eq('tenancy_id', tenantId)
          .order('period_month', ascending: false);
      if (periodRows.isEmpty) return const Ok([]);
      final tenancies = await _tenanciesById([tenantId]);
      final tenancy = tenancies[tenantId];
      if (tenancy == null) return const Ok([]);
      return Ok([for (final row in periodRows) _toRentPayment(row, tenancy)]);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> recordPayment(
    String paymentId, {
    required PaymentMethod method,
    required int amount,
    required DateTime date,
    String? idempotencyKey,
  }) async {
    try {
      await _client.rpc(
        'record_payment',
        params: {
          'p_rent_period_id': paymentId,
          'p_method': _methodToDb(method),
          'p_amount': amount,
          if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
        },
      );
      return const Ok(null);
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> recordSelfPayment(
    String paymentId, {
    required PaymentMethod method,
    required int amount,
    required DateTime date,
    String? idempotencyKey,
  }) async {
    try {
      await _client.rpc(
        'record_self_payment',
        params: {
          'p_rent_period_id': paymentId,
          'p_method': _methodToDb(method),
          'p_amount': amount,
          if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
        },
      );
      return const Ok(null);
    } on PostgrestException catch (e) {
      // See migration 34: record_self_payment now rejects an amount that
      // doesn't exactly match what's still owed (or a period that's
      // already fully paid) — surface that distinctly instead of a generic
      // failure, since it's a real, recoverable case (the amount just
      // changed under the tenant, e.g. staff recorded a payment first).
      if (e.message.contains('amount_mismatch') ||
          e.message.contains('already_paid')) {
        return const Err(PaymentAmountMismatchFailure());
      }
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> confirmPayment(String paymentId) async {
    return _withLatestPaymentId(paymentId, (latestPaymentId) async {
      await _client.rpc(
        'confirm_payment',
        params: {'p_payment_id': latestPaymentId},
      );
    });
  }

  @override
  Future<Result<void>> disputePayment(String paymentId) async {
    return _withLatestPaymentId(paymentId, (latestPaymentId) async {
      await _client.rpc(
        'dispute_payment',
        params: {'p_payment_id': latestPaymentId},
      );
    });
  }

  @override
  Future<Result<void>> voidPayment(String paymentId) async {
    return _withLatestPaymentId(paymentId, (latestPaymentId) async {
      await _client.rpc(
        'void_payment',
        params: {'p_payment_id': latestPaymentId},
      );
    });
  }

  @override
  Future<Result<void>> resolveDispute(
    String paymentId, {
    required bool paid,
    required String note,
  }) async {
    return _withLatestPaymentId(paymentId, (latestPaymentId) async {
      await _client.rpc(
        'resolve_dispute',
        params: {
          'p_payment_id': latestPaymentId,
          'p_outcome': paid ? 'paid' : 'voided',
          'p_note': note,
        },
      );
    });
  }

  Future<Result<void>> _withLatestPaymentId(
    String rentPeriodId,
    Future<void> Function(String latestPaymentId) action,
  ) async {
    try {
      final row = await _client
          .from('rent_period_status')
          .select('latest_payment_id')
          .eq('rent_period_id', rentPeriodId)
          .maybeSingle();
      final latestPaymentId = row?['latest_payment_id'] as String?;
      if (latestPaymentId == null) return const Err(UnexpectedFailure());
      await action(latestPaymentId);
      return const Ok(null);
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  Future<Map<String, Map<String, dynamic>>> _tenanciesById(
    Iterable<String> ids,
  ) async {
    final idList = ids.toList();
    if (idList.isEmpty) return {};
    final rows = await _client
        .from('tenancies')
        .select(_tenancySelectColumns)
        .inFilter('id', idList);
    return {for (final row in rows) row['id'] as String: row};
  }

  RentPayment _toRentPayment(
    Map<String, dynamic> periodRow,
    Map<String, dynamic> tenancyRow,
  ) {
    final bed = tenancyRow['beds'] as Map<String, dynamic>;
    final room = bed['rooms'] as Map<String, dynamic>;
    final property = room['properties'] as Map<String, dynamic>;
    final tenant = tenancyRow['tenant'] as Map<String, dynamic>;
    final amountDue = (periodRow['amount_due'] as num).round();
    // paid_amount = confirmed (status='paid') total across every
    // allocation — the real settled amount, correct for paid/partial.
    // latest_amount = the latest attempt's own claimed amount regardless
    // of ITS status (NULL if there's never been one) — what an
    // awaiting_confirmation/disputed claim actually said. These are
    // different numbers (see backend migration 39); picking the wrong one
    // for a given status previously showed ₹0 for every untouched
    // pending/overdue period instead of falling back to amountDue.
    final paidAmount = (periodRow['paid_amount'] as num?)?.round();
    final latestAmount = (periodRow['latest_amount'] as num?)?.round();
    final method = periodRow['method'] as String?;
    final paidAt = periodRow['paid_at'] as String?;
    final status = _statusFromDb(periodRow['status'] as String);
    final amount = switch (status) {
      PaymentStatus.paid || PaymentStatus.partial => paidAmount ?? amountDue,
      PaymentStatus.awaitingConfirmation ||
      PaymentStatus.disputed => latestAmount ?? amountDue,
      PaymentStatus.pending || PaymentStatus.overdue => amountDue,
    };
    return RentPayment(
      id: periodRow['rent_period_id'] as String,
      tenantId: tenancyRow['id'] as String,
      tenantName: tenant['full_name'] as String,
      propertyId: property['id'] as String,
      propertyName: property['name'] as String,
      room: '${room['room_number']} - ${bed['label']}',
      amount: amount,
      expectedAmount: amountDue,
      periodMonth: DateTime.parse(periodRow['period_month'] as String),
      dueDate: DateTime.parse(periodRow['due_date'] as String),
      status: status,
      method: method == null ? null : _methodFromDb(method),
      paidDate: paidAt == null ? null : DateTime.parse(paidAt),
    );
  }

  String _methodToDb(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => 'cash',
    PaymentMethod.upi => 'upi',
    PaymentMethod.card => 'card',
    PaymentMethod.bankTransfer => 'bank_transfer',
  };

  PaymentMethod _methodFromDb(String value) => switch (value) {
    'cash' => PaymentMethod.cash,
    'upi' => PaymentMethod.upi,
    'card' => PaymentMethod.card,
    'bank_transfer' => PaymentMethod.bankTransfer,
    _ => throw StateError('Unknown payment method from database: $value'),
  };

  PaymentStatus _statusFromDb(String value) => switch (value) {
    'pending' => PaymentStatus.pending,
    'overdue' => PaymentStatus.overdue,
    'awaiting_confirmation' => PaymentStatus.awaitingConfirmation,
    'paid' => PaymentStatus.paid,
    'partial' => PaymentStatus.partial,
    'disputed' => PaymentStatus.disputed,
    _ => throw StateError('Unknown payment status from database: $value'),
  };
}
