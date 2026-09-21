import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/result.dart';
import 'package:pg_khata/features/payments/data/mock_payments_repository.dart';
import 'package:pg_khata/features/payments/domain/payment_method.dart';
import 'package:pg_khata/features/payments/domain/payment_status.dart';

void main() {
  late MockPaymentsRepository repository;

  setUp(() => repository = MockPaymentsRepository());

  test(
    'fetchLatestPayments for HSR sums to Manager Today\'s ₹25,000 pending total',
    () async {
      final result = await repository.fetchLatestPayments(propertyId: 'hsr');
      final payments = result.when(ok: (p) => p, err: (_) => null);
      expect(payments, isNotNull);

      final outstanding = payments!
          .where((p) => p.status.isCollectable)
          .fold<int>(0, (total, p) => total + p.amount);
      expect(outstanding, 25000);

      final names = payments
          .where((p) => p.status.isCollectable)
          .map((p) => p.tenantName)
          .toSet();
      expect(names, {'Rahul Sharma', 'Ayesha Khan', 'Vikram Rao'});
    },
  );

  test('fetchLatestPayments returns one row per tenant, not per period', () async {
    final result = await repository.fetchLatestPayments(propertyId: 'hsr');
    final payments = result.when(ok: (p) => p, err: (_) => null)!;
    final rahulRows = payments.where((p) => p.tenantId == 't7');
    expect(rahulRows.length, 1);
    expect(rahulRows.single.periodMonth, DateTime(2026, 9));
  });

  test('fetchPaymentHistory returns every period, newest first', () async {
    final result = await repository.fetchPaymentHistory('t7');
    final history = result.when(ok: (p) => p, err: (_) => null);
    expect(history, isNotNull);
    expect(history!.length, 5);
    expect(
      history.map((p) => p.periodMonth),
      [
        DateTime(2026, 9),
        DateTime(2026, 8),
        DateTime(2026, 7),
        DateTime(2026, 6),
        DateTime(2026, 5),
      ],
    );
  });

  test('recording a cash payment moves it to awaiting confirmation', () async {
    await repository.recordPayment(
      't7_202609',
      method: PaymentMethod.cash,
      amount: 8500,
      date: DateTime(2026, 9, 20),
    );
    final history = (await repository.fetchPaymentHistory('t7'))
        .when(ok: (p) => p, err: (_) => null)!;
    final september = history.firstWhere(
      (p) => p.periodMonth == DateTime(2026, 9),
    );
    expect(september.status, PaymentStatus.awaitingConfirmation);
    expect(september.method, PaymentMethod.cash);
  });

  test(
    'recording a UPI payment (staff-entered) still needs confirmation',
    () async {
      // A Manager/Owner typing "UPI" is just as much a secondhand claim as
      // cash — only the tenant's own in-app payment is self-verifying.
      await repository.recordPayment(
        't7_202609',
        method: PaymentMethod.upi,
        amount: 8500,
        date: DateTime(2026, 9, 20),
      );
      final history = (await repository.fetchPaymentHistory('t7'))
          .when(ok: (p) => p, err: (_) => null)!;
      final september = history.firstWhere(
        (p) => p.periodMonth == DateTime(2026, 9),
      );
      expect(september.status, PaymentStatus.awaitingConfirmation);
      expect(september.method, PaymentMethod.upi);
    },
  );

  test('a tenant paying through the app settles instantly, any method', () async {
    await repository.recordSelfPayment(
      't7_202609',
      method: PaymentMethod.upi,
      amount: 8500,
      date: DateTime(2026, 9, 20),
    );
    final history = (await repository.fetchPaymentHistory('t7'))
        .when(ok: (p) => p, err: (_) => null)!;
    final september = history.firstWhere(
      (p) => p.periodMonth == DateTime(2026, 9),
    );
    expect(september.status, PaymentStatus.paid);
  });

  test('recording a payment actually updates the stored amount', () async {
    await repository.recordPayment(
      't7_202609',
      method: PaymentMethod.upi,
      amount: 8000,
      date: DateTime(2026, 9, 20),
    );
    final history = (await repository.fetchPaymentHistory('t7'))
        .when(ok: (p) => p, err: (_) => null)!;
    final september = history.firstWhere(
      (p) => p.periodMonth == DateTime(2026, 9),
    );
    expect(september.amount, 8000);
    expect(september.expectedAmount, 8500);
  });

  test('confirmPayment settles an awaiting-confirmation period', () async {
    final result = await repository.confirmPayment('t7_202608');
    expect(result, isA<Ok<void>>());
    final history = (await repository.fetchPaymentHistory('t7'))
        .when(ok: (p) => p, err: (_) => null)!;
    final august = history.firstWhere(
      (p) => p.periodMonth == DateTime(2026, 8),
    );
    expect(august.status, PaymentStatus.paid);
  });

  test('disputePayment marks a period disputed', () async {
    final result = await repository.disputePayment('t7_202608');
    expect(result, isA<Ok<void>>());
    final history = (await repository.fetchPaymentHistory('t7'))
        .when(ok: (p) => p, err: (_) => null)!;
    final august = history.firstWhere(
      (p) => p.periodMonth == DateTime(2026, 8),
    );
    expect(august.status, PaymentStatus.disputed);
  });

  test('voidPayment restores the expected amount and clears the method', () async {
    await repository.recordPayment(
      't7_202609',
      method: PaymentMethod.upi,
      amount: 8000,
      date: DateTime(2026, 9, 20),
    );
    final result = await repository.voidPayment('t7_202609');
    expect(result, isA<Ok<void>>());
    final history = (await repository.fetchPaymentHistory('t7'))
        .when(ok: (p) => p, err: (_) => null)!;
    final september = history.firstWhere(
      (p) => p.periodMonth == DateTime(2026, 9),
    );
    expect(september.amount, september.expectedAmount);
    expect(september.method, isNull);
    expect(september.paidDate, isNull);
    expect(
      september.status,
      anyOf(PaymentStatus.pending, PaymentStatus.overdue),
    );
  });
}
