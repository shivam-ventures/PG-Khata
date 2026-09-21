import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/payment_method.dart';
import '../domain/payment_status.dart';
import '../domain/rent_payment.dart';
import 'payments_repository.dart';

const _propertyNames = {
  'hsr': 'HSR PG',
  'kor': 'Koramangala PG',
  'ind': 'Indiranagar PG',
};

/// Phase-3 mock backing for [PaymentsRepository]. Reconciles `Manager
/// Payments.dc.html`, `Owner Payments.dc.html` and `Tenant Payments.dc.html`'s
/// mock data into one ledger, keyed to the tenant roster from
/// `MockTenantsRepository` — same reconciliation approach as Phase 1's
/// Rooms/Tenants merge. September's HSR total (₹25,000 pending across Rahul
/// Sharma, Ayesha Khan and Vikram Rao) matches `Manager Today.dc.html`'s
/// already-shipped mini-stat exactly, so every other HSR tenant here is
/// seeded as already paid.
class MockPaymentsRepository implements PaymentsRepository {
  final List<RentPayment> _payments = [
    // HSR PG — settled tenants.
    RentPayment(
      id: 't1_202609',
      tenantId: 't1',
      tenantName: 'Ravi Kumar',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: '101 - A',
      amount: 6500,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 5),
      status: PaymentStatus.paid,
      method: PaymentMethod.upi,
      paidDate: DateTime(2026, 9, 3),
    ),
    RentPayment(
      id: 't2_202609',
      tenantId: 't2',
      tenantName: 'Amit Shah',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: '101 - B',
      amount: 6500,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 5),
      status: PaymentStatus.paid,
      method: PaymentMethod.upi,
      paidDate: DateTime(2026, 9, 4),
    ),
    RentPayment(
      id: 't3_202609',
      tenantId: 't3',
      tenantName: 'Suresh Naik',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: '102 - A',
      amount: 7500,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 10),
      status: PaymentStatus.paid,
      method: PaymentMethod.cash,
      paidDate: DateTime(2026, 9, 2),
    ),
    RentPayment(
      id: 't4_202609',
      tenantId: 't4',
      tenantName: 'Deepak Rao',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: '102 - B',
      amount: 7500,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 10),
      status: PaymentStatus.paid,
      method: PaymentMethod.bankTransfer,
      paidDate: DateTime(2026, 9, 6),
    ),
    RentPayment(
      id: 't5_202609',
      tenantId: 't5',
      tenantName: 'Manoj Patil',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: '201 - A',
      amount: 6500,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 20),
      status: PaymentStatus.paid,
      method: PaymentMethod.upi,
      paidDate: DateTime(2026, 9, 8),
    ),

    // HSR PG — the three tenants Manager Today's "Rent to collect" already lists.
    RentPayment(
      id: 't6_202609',
      tenantId: 't6',
      tenantName: 'Ayesha Khan',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: 'A-108 - A',
      amount: 9000,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 25),
      status: PaymentStatus.overdue,
    ),
    RentPayment(
      id: 't7_202609',
      tenantId: 't7',
      tenantName: 'Rahul Sharma',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: 'B-204 - A',
      amount: 8500,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 28),
      status: PaymentStatus.pending,
    ),
    RentPayment(
      id: 't8_202609',
      tenantId: 't8',
      tenantName: 'Vikram Rao',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: 'C-301 - A',
      amount: 7500,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 28),
      status: PaymentStatus.pending,
    ),

    // Rahul Sharma's earlier periods — his persona is also Tenant Home's,
    // so this history matches `Tenant Payments.dc.html`'s mock exactly.
    RentPayment(
      id: 't7_202608',
      tenantId: 't7',
      tenantName: 'Rahul Sharma',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: 'B-204 - A',
      amount: 8500,
      periodMonth: DateTime(2026, 8),
      dueDate: DateTime(2026, 8, 28),
      status: PaymentStatus.awaitingConfirmation,
      method: PaymentMethod.cash,
      paidDate: DateTime(2026, 8, 3),
    ),
    RentPayment(
      id: 't7_202607',
      tenantId: 't7',
      tenantName: 'Rahul Sharma',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: 'B-204 - A',
      amount: 8500,
      periodMonth: DateTime(2026, 7),
      dueDate: DateTime(2026, 7, 28),
      status: PaymentStatus.paid,
      method: PaymentMethod.cash,
      paidDate: DateTime(2026, 7, 2),
    ),
    RentPayment(
      id: 't7_202606',
      tenantId: 't7',
      tenantName: 'Rahul Sharma',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: 'B-204 - A',
      amount: 8500,
      periodMonth: DateTime(2026, 6),
      dueDate: DateTime(2026, 6, 28),
      status: PaymentStatus.paid,
      method: PaymentMethod.upi,
      paidDate: DateTime(2026, 6, 4),
    ),
    RentPayment(
      id: 't7_202605',
      tenantId: 't7',
      tenantName: 'Rahul Sharma',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      room: 'B-204 - A',
      amount: 8500,
      periodMonth: DateTime(2026, 5),
      dueDate: DateTime(2026, 5, 28),
      status: PaymentStatus.paid,
      method: PaymentMethod.upi,
      paidDate: DateTime(2026, 5, 5),
    ),

    // Koramangala PG.
    RentPayment(
      id: 't9_202609',
      tenantId: 't9',
      tenantName: 'Vikas Gowda',
      propertyId: 'kor',
      propertyName: _propertyNames['kor']!,
      room: 'G1 - A',
      amount: 8000,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 3),
      status: PaymentStatus.paid,
      method: PaymentMethod.upi,
      paidDate: DateTime(2026, 9, 2),
    ),
    RentPayment(
      id: 't10_202609',
      tenantId: 't10',
      tenantName: 'Rahul Jain',
      propertyId: 'kor',
      propertyName: _propertyNames['kor']!,
      room: 'G1 - B',
      amount: 8000,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 28),
      status: PaymentStatus.pending,
    ),

    // Indiranagar PG.
    RentPayment(
      id: 't11_202609',
      tenantId: 't11',
      tenantName: 'Priya Menon',
      propertyId: 'ind',
      propertyName: _propertyNames['ind']!,
      room: 'G1 - A',
      amount: 12000,
      periodMonth: DateTime(2026, 9),
      dueDate: DateTime(2026, 9, 2),
      status: PaymentStatus.paid,
      method: PaymentMethod.bankTransfer,
      paidDate: DateTime(2026, 9, 1),
    ),
  ];

  @override
  Future<Result<List<RentPayment>>> fetchLatestPayments({
    String? propertyId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final scoped = propertyId == null
        ? _payments
        : _payments.where((p) => p.propertyId == propertyId).toList();
    final latestByTenant = <String, RentPayment>{};
    for (final payment in scoped) {
      final current = latestByTenant[payment.tenantId];
      if (current == null || payment.periodMonth.isAfter(current.periodMonth)) {
        latestByTenant[payment.tenantId] = payment;
      }
    }
    return Ok(List.unmodifiable(latestByTenant.values));
  }

  @override
  Future<Result<List<RentPayment>>> fetchPaymentHistory(
    String tenantId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final history = _payments.where((p) => p.tenantId == tenantId).toList()
      ..sort((a, b) => b.periodMonth.compareTo(a.periodMonth));
    return Ok(List.unmodifiable(history));
  }

  @override
  Future<Result<void>> recordPayment(
    String paymentId, {
    required PaymentMethod method,
    required int amount,
    required DateTime date,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return const Err(UnexpectedFailure());
    // Staff-recorded, whatever the method — always provisional until the
    // tenant confirms. See the interface doc comment for why.
    _payments[index] = _payments[index].copyWith(
      status: PaymentStatus.awaitingConfirmation,
      method: method,
      paidDate: date,
      amount: amount,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> recordSelfPayment(
    String paymentId, {
    required PaymentMethod method,
    required int amount,
    required DateTime date,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return const Err(UnexpectedFailure());
    _payments[index] = _payments[index].copyWith(
      status: PaymentStatus.paid,
      method: method,
      paidDate: date,
      amount: amount,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> confirmPayment(String paymentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return const Err(UnexpectedFailure());
    _payments[index] = _payments[index].copyWith(status: PaymentStatus.paid);
    return const Ok(null);
  }

  @override
  Future<Result<void>> disputePayment(String paymentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return const Err(UnexpectedFailure());
    _payments[index] = _payments[index].copyWith(
      status: PaymentStatus.disputed,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> voidPayment(String paymentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return const Err(UnexpectedFailure());
    final payment = _payments[index];
    final isPastDue = payment.dueDate.isBefore(DateTime.now());
    _payments[index] = payment.copyWith(
      status: isPastDue ? PaymentStatus.overdue : PaymentStatus.pending,
      amount: payment.expectedAmount,
      clearMethodAndPaidDate: true,
    );
    return const Ok(null);
  }
}
