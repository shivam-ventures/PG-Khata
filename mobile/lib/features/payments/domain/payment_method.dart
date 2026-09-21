/// How a rent payment was settled. Matches the method dropdown on both the
/// Manager's Collect Rent dialog and the Owner's Record Payment dialog, plus
/// [card] for a Tenant's own online payment (`PayRentDialog`).
enum PaymentMethod {
  cash,
  upi,
  card,
  bankTransfer;

  String get label => switch (this) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.upi => 'UPI',
    PaymentMethod.card => 'Card',
    PaymentMethod.bankTransfer => 'Bank Transfer',
  };
}
