import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/semantic_tone.dart';

/// How a tenancy's security deposit was resolved at move-out — decided
/// once, by [TenantRecord.canGiveNotice]'s notice-period rule (see
/// `evaluate_move_out_notice` in the backend), then only ever updated by
/// staff explicitly confirming the money actually changed hands. `null` on
/// [TenantRecord] means no deposit was ever collected, or no move-out has
/// been requested yet — there's nothing to show in either case.
enum DepositSettlement {
  pending,
  forfeited,
  returned;

  /// Unlocalized — kept only for call sites not yet migrated. Prefer
  /// [labelFor].
  String get label => switch (this) {
    DepositSettlement.pending => 'Deposit pending',
    DepositSettlement.forfeited => 'Deposit forfeited',
    DepositSettlement.returned => 'Deposit returned',
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    DepositSettlement.pending => l10n.depositStatusPending,
    DepositSettlement.forfeited => l10n.depositStatusForfeited,
    DepositSettlement.returned => l10n.depositStatusReturned,
  };

  SemanticTone get tone => switch (this) {
    DepositSettlement.pending => SemanticTone.warning,
    DepositSettlement.forfeited => SemanticTone.danger,
    DepositSettlement.returned => SemanticTone.success,
  };
}
