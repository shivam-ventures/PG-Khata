import '../../../l10n/app_localizations.dart';

/// How a rent payment was settled. Matches the method dropdown on both the
/// Manager's Collect Rent dialog and the Owner's Record Payment dialog, plus
/// [card] for a Tenant's own online payment (`PayRentDialog`).
enum PaymentMethod {
  cash,
  upi,
  card,
  bankTransfer;

  /// Unlocalized — kept only for call sites not yet migrated. Prefer
  /// [labelFor].
  String get label => switch (this) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.upi => 'UPI',
    PaymentMethod.card => 'Card',
    PaymentMethod.bankTransfer => 'Bank Transfer',
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    PaymentMethod.cash => l10n.paymentMethodCash,
    PaymentMethod.upi => l10n.paymentMethodUpi,
    PaymentMethod.card => l10n.paymentMethodCard,
    PaymentMethod.bankTransfer => l10n.paymentMethodBankTransfer,
  };
}
