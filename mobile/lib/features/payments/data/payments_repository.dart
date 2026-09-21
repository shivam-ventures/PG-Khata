import '../../../core/errors/result.dart';
import '../domain/payment_method.dart';
import '../domain/rent_payment.dart';

/// The rent ledger. [fetchLatestPayments] backs the Manager's Collect Rent
/// list and the Owner's portfolio ledger (each tenant's current period
/// only); [fetchPaymentHistory] backs a tenant's own Rent & Payments screen
/// (every period they've had). Swap the implementation for a Supabase-backed
/// one in Phase 6.
abstract interface class PaymentsRepository {
  Future<Result<List<RentPayment>>> fetchLatestPayments({String? propertyId});

  Future<Result<List<RentPayment>>> fetchPaymentHistory(String tenantId);

  /// A Manager/Owner recording a payment on a tenant's behalf — this is
  /// always a secondhand claim from the app's point of view (nobody but the
  /// tenant can actually verify it, regardless of which method they say was
  /// used), so it always lands on [PaymentStatus.awaitingConfirmation]
  /// rather than [PaymentStatus.paid]. Only [recordSelfPayment] — the
  /// tenant paying through the app's own online flow — settles instantly.
  Future<Result<void>> recordPayment(
    String paymentId, {
    required PaymentMethod method,
    required int amount,
    required DateTime date,
  });

  /// The tenant paying their own rent through the app (UPI/Card via
  /// `PayRentDialog`). Unlike [recordPayment], this settles straight to
  /// [PaymentStatus.paid] — it's the one path that's actually verified by
  /// the transaction itself rather than taken on someone's word.
  Future<Result<void>> recordSelfPayment(
    String paymentId, {
    required PaymentMethod method,
    required int amount,
    required DateTime date,
  });

  Future<Result<void>> confirmPayment(String paymentId);

  Future<Result<void>> disputePayment(String paymentId);

  /// Undoes a mistaken entry (wrong tenant, wrong amount, wrong method) —
  /// puts the period back to Pending/Overdue with no method, amount
  /// restored to the tenant's on-record rent, and no paid date. There is no
  /// separate "edit" action: correcting a mistake means voiding it and
  /// recording it again, so the ledger never silently rewrites what was
  /// actually entered.
  Future<Result<void>> voidPayment(String paymentId);
}
