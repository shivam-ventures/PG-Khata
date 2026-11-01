import '../../../l10n/app_localizations.dart';

/// The three account roles the design supports. `super_admin` exists in the
/// pre-pivot schema for internal/support use only and has no end-user UI —
/// see `docs/design-readme-reconciliation.md` §2 — so it's deliberately not
/// modeled here.
enum UserRole {
  owner,
  manager,
  tenant;

  /// Unlocalized — kept only for call sites (mostly Owner/Manager screens)
  /// not yet migrated to [labelFor]. Prefer [labelFor] in any new/updated
  /// widget, which has a `BuildContext` to resolve [AppLocalizations] from.
  String get label => switch (this) {
    UserRole.owner => 'Owner',
    UserRole.manager => 'Manager',
    UserRole.tenant => 'Tenant',
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    UserRole.owner => l10n.roleOwner,
    UserRole.manager => l10n.roleManager,
    UserRole.tenant => l10n.roleTenant,
  };
}
