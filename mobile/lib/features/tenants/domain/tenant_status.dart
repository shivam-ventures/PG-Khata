import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/semantic_tone.dart';

/// A tenant's lifecycle status. Matches the design and pre-pivot schema
/// exactly — `pending_profile`/self-registration states are a separate,
/// not-yet-adopted product decision (see `PendingTenant`).
enum TenantStatus {
  active,
  noticePeriod,
  vacated;

  /// Unlocalized — kept only for call sites not yet migrated. Prefer
  /// [labelFor].
  String get label => switch (this) {
    TenantStatus.active => 'Active',
    TenantStatus.noticePeriod => 'Notice period',
    TenantStatus.vacated => 'Vacated',
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    TenantStatus.active => l10n.tenantStatusActive,
    TenantStatus.noticePeriod => l10n.tenantStatusNoticePeriod,
    TenantStatus.vacated => l10n.tenantStatusVacated,
  };

  SemanticTone get tone => switch (this) {
    TenantStatus.active => SemanticTone.success,
    TenantStatus.noticePeriod => SemanticTone.warning,
    TenantStatus.vacated => SemanticTone.neutral,
  };
}
