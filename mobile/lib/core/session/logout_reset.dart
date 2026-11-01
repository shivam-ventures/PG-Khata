import 'package:flutter_riverpod/flutter_riverpod.dart';
// ProviderOrFamily isn't in the main flutter_riverpod.dart barrel export.
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../features/announcements/application/announcements_providers.dart';
import '../../features/audit_log/application/audit_log_providers.dart';
import '../../features/complaints/application/complaints_providers.dart';
import '../../features/dashboard/application/dashboard_providers.dart';
import '../../features/notifications/application/notifications_providers.dart';
import '../../features/payments/application/payments_providers.dart';
import '../../features/properties/application/properties_providers.dart';
import '../../features/reports/application/reports_providers.dart';
import '../../features/rooms/application/rooms_providers.dart';
import '../../features/tenants/application/tenants_providers.dart';

/// Every provider that holds data (or a UI selection) scoped to whoever is
/// currently signed in. [AuthController.logout] invalidates all of these —
/// see the comment there for why: none of them watch auth state, so without
/// this they stay cached for the app process's lifetime and a second user
/// signing in on the same device (shared/handoff device, or a demo unit)
/// could briefly see the previous user's properties/tenants/payments/etc.
/// before each screen happens to refetch on its own.
///
/// This lives in its own file, not directly in `auth_controller.dart`,
/// because several of these provider files already import
/// `auth_controller.dart` (to watch `authControllerProvider`) — importing
/// them back from there would be circular.
///
/// IMPORTANT: when you add a new provider that reads data scoped to the
/// signed-in user (an Owner/Manager/Tenant's own rows, or a UI selection
/// like "which PG am I viewing"), add it to this list. A provider that
/// only reads globally-public data (e.g. `publicPropertiesProvider`,
/// `tenantInviteProvider`) does not belong here.
final List<ProviderOrFamily> userScopedProviders = [
  propertiesProvider,
  propertyMetricsProvider,
  orgManagersProvider,
  roomsProvider,
  selectedPropertyIdProvider,
  tenantsProvider,
  pendingTenantsProvider,
  currentTenantRecordProvider,
  latestPaymentsProvider,
  paymentHistoryProvider,
  managerComplaintsProvider,
  tenantComplaintsProvider,
  portfolioComplaintsProvider,
  announcementsProvider,
  currentAnnouncementProvider,
  notificationsProvider,
  unreadNotificationsCountProvider,
  auditLogProvider,
  reportsProvider,
  managerSelectedPgIdProvider,
  // Deliberately NOT listing ownerDashboardProvider/managerTodayProvider/
  // tenantHomeProvider here, even though they're user-scoped too: each of
  // them `ref.watch`es several of the providers already invalidated above
  // (propertiesProvider, latestPaymentsProvider, ...), which gives Riverpod
  // a real dependency edge — invalidating those already correctly
  // propagates to these composed providers on their next read. Explicitly
  // invalidating them too, in the same synchronous loop as their own
  // dependencies, caused a real `CircularDependencyError` at logout (a
  // still-alive watcher of e.g. ownerDashboardProvider re-entering it
  // mid-rebuild from an earlier invalidation in this same list) — found
  // while testing this fix live, 2026-09-25. Don't add them back.
];

void resetUserScopedProviders(Ref ref) {
  for (final provider in userScopedProviders) {
    ref.invalidate(provider);
  }
}
