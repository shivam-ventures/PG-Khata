/// The three account roles the design supports. `super_admin` exists in the
/// pre-pivot schema for internal/support use only and has no end-user UI —
/// see `docs/design-readme-reconciliation.md` §2 — so it's deliberately not
/// modeled here.
enum UserRole {
  owner,
  manager,
  tenant;

  String get label => switch (this) {
    UserRole.owner => 'Owner',
    UserRole.manager => 'Manager',
    UserRole.tenant => 'Tenant',
  };
}
