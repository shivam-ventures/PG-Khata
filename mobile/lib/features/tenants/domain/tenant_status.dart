import '../../../shared/widgets/semantic_tone.dart';

/// A tenant's lifecycle status. Matches the design and pre-pivot schema
/// exactly — `pending_profile`/self-registration states are a separate,
/// not-yet-adopted product decision (see `PendingTenant`).
enum TenantStatus {
  active,
  noticePeriod,
  vacated;

  String get label => switch (this) {
    TenantStatus.active => 'Active',
    TenantStatus.noticePeriod => 'Notice period',
    TenantStatus.vacated => 'Vacated',
  };

  SemanticTone get tone => switch (this) {
    TenantStatus.active => SemanticTone.success,
    TenantStatus.noticePeriod => SemanticTone.warning,
    TenantStatus.vacated => SemanticTone.neutral,
  };
}
