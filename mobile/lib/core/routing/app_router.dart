import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/announcements/presentation/manager/manager_announcements_screen.dart';
import '../../features/announcements/presentation/owner/owner_announcements_screen.dart';
import '../../features/audit_log/presentation/audit_log_screen.dart';
import '../../features/auth/presentation/account_menu_screen.dart';
import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/auth/presentation/phone_entry_screen.dart';
import '../../features/complaints/presentation/manager/manager_complaints_screen.dart';
import '../../features/complaints/presentation/owner/owner_complaints_screen.dart';
import '../../features/complaints/presentation/tenant/tenant_complaints_screen.dart';
import '../../features/dashboard/presentation/manager/manager_today_screen.dart';
import '../../features/dashboard/presentation/owner/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/tenant/tenant_home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/join_invite_screen.dart';
import '../../features/onboarding/presentation/self_register_screen.dart';
import '../../features/payments/presentation/manager/manager_payments_screen.dart';
import '../../features/payments/presentation/owner/owner_payments_screen.dart';
import '../../features/payments/presentation/tenant/tenant_payments_screen.dart';
import '../../features/properties/presentation/owner_properties_screen.dart';
import '../../features/reports/presentation/owner_reports_screen.dart';
import '../../features/rooms/presentation/manager/manager_rooms_screen.dart';
import '../../features/rooms/presentation/owner/owner_rooms_screen.dart';
import '../../features/tenants/presentation/manager/manager_tenants_screen.dart';
import '../../features/tenants/presentation/owner/owner_tenants_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/role_shell.dart';
import '../../shared/widgets/role_bottom_nav.dart';
import 'app_route.dart';

/// The app's router. Redirect enforces two things `go_router` can't express
/// declaratively: an unauthenticated session can only see `/login/*`, and a
/// signed-in session can only see the branch matching their own role — this
/// is routing UX only, per `docs/architecture.md`; the real security
/// boundary is Postgres RLS once the database phase adds one.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoute.login,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      if (authState.isLoading) return null;

      final user = authState.value;
      final isLoggingIn = state.matchedLocation.startsWith(AppRoute.login);
      final isJoiningByInvite = state.matchedLocation.startsWith(
        AppRoute.joinPrefix,
      );
      final isSelfRegistering = state.matchedLocation.startsWith(
        AppRoute.register,
      );

      if (user == null) {
        // The invite-link and direct self-registration flows are both
        // reachable while signed out — each *is* a sign-in path of its own
        // (Auth.dc.html's hasInvite branch, plus the "no invite" case), not
        // a page that needs an existing session.
        if (isJoiningByInvite || isSelfRegistering) return null;
        return isLoggingIn ? null : AppRoute.login;
      }

      final rolePrefix = switch (user.role) {
        UserRole.owner => AppRoute.ownerHome,
        UserRole.manager => AppRoute.managerToday,
        UserRole.tenant => AppRoute.tenantHome,
      };
      if (isLoggingIn || !state.matchedLocation.startsWith(rolePrefix)) {
        return rolePrefix;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoute.login,
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: AppRoute.verifyOtp,
        builder: (context, state) => OtpVerificationScreen(
          phoneNumber: state.uri.queryParameters['phone'] ?? '',
        ),
      ),
      GoRoute(
        path: '${AppRoute.joinPrefix}/:token',
        builder: (context, state) =>
            JoinInviteScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: AppRoute.register,
        builder: (context, state) => const SelfRegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleShell(
          navigationShell: shell,
          items: _ownerNavItems(AppLocalizations.of(context)),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.ownerHome,
                builder: (context, state) => const OwnerDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.ownerProperties,
                builder: (context, state) => const OwnerPropertiesScreen(),
                routes: [
                  GoRoute(
                    path: 'rooms',
                    builder: (context, state) => OwnerRoomsScreen(
                      initialPropertyId: state.uri.queryParameters['property'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.ownerTenants,
                builder: (context, state) => const OwnerTenantsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.ownerMore,
                builder: (context, state) => AccountMenuScreen(
                  extraMenuItems: [
                    AccountMenuItem(
                      icon: Icons.payments_outlined,
                      label: AppLocalizations.of(context).ownerPayments,
                      onTap: () => context.push(AppRoute.ownerPayments),
                    ),
                    AccountMenuItem(
                      icon: Icons.bar_chart_outlined,
                      label: AppLocalizations.of(context).ownerReports,
                      onTap: () => context.push(AppRoute.ownerReports),
                    ),
                    AccountMenuItem(
                      icon: Icons.report_problem_outlined,
                      label: AppLocalizations.of(context).complaintsTitle,
                      onTap: () => context.push(AppRoute.ownerComplaints),
                    ),
                    AccountMenuItem(
                      icon: Icons.history,
                      label: AppLocalizations.of(context).auditLogTitle,
                      onTap: () => context.push(AppRoute.ownerAuditLog),
                    ),
                    AccountMenuItem(
                      icon: Icons.campaign_outlined,
                      label: AppLocalizations.of(context).announcementsTitle,
                      onTap: () => context.push(AppRoute.ownerAnnouncements),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.ownerPayments,
        builder: (context, state) => const OwnerPaymentsScreen(),
      ),
      GoRoute(
        path: AppRoute.ownerReports,
        builder: (context, state) => const OwnerReportsScreen(),
      ),
      GoRoute(
        path: AppRoute.ownerComplaints,
        builder: (context, state) => const OwnerComplaintsScreen(),
      ),
      GoRoute(
        path: AppRoute.ownerAuditLog,
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: AppRoute.ownerNotifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoute.ownerAnnouncements,
        builder: (context, state) => const OwnerAnnouncementsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleShell(
          navigationShell: shell,
          items: _managerNavItems(AppLocalizations.of(context)),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.managerToday,
                builder: (context, state) => const ManagerTodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.managerPayments,
                builder: (context, state) => const ManagerPaymentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.managerRooms,
                builder: (context, state) => const ManagerRoomsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.managerMore,
                builder: (context, state) => AccountMenuScreen(
                  extraMenuItems: [
                    AccountMenuItem(
                      icon: Icons.people_outline,
                      label: AppLocalizations.of(context).tenantsTitle,
                      onTap: () => context.push(AppRoute.managerTenants),
                    ),
                    AccountMenuItem(
                      icon: Icons.report_problem_outlined,
                      label: AppLocalizations.of(context).complaintsTitle,
                      onTap: () => context.push(AppRoute.managerComplaints),
                    ),
                    AccountMenuItem(
                      icon: Icons.campaign_outlined,
                      label: AppLocalizations.of(context).announcementsTitle,
                      onTap: () => context.push(AppRoute.managerAnnouncements),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.managerTenants,
        builder: (context, state) => ManagerTenantsScreen(
          initialRoom: state.uri.queryParameters['room'],
          initialBed: state.uri.queryParameters['bed'],
          autoOpenAdd: state.uri.queryParameters['add'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoute.managerComplaints,
        builder: (context, state) => const ManagerComplaintsScreen(),
      ),
      GoRoute(
        path: AppRoute.managerNotifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoute.managerAnnouncements,
        builder: (context, state) => const ManagerAnnouncementsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleShell(
          navigationShell: shell,
          items: _tenantNavItems(AppLocalizations.of(context)),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.tenantHome,
                builder: (context, state) => const TenantHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.tenantPayments,
                builder: (context, state) => const TenantPaymentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.tenantComplaints,
                builder: (context, state) => const TenantComplaintsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.tenantProfile,
                builder: (context, state) => const AccountMenuScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.tenantNotifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text("That page doesn't exist: ${state.uri}")),
    ),
  );
});

List<NavItem> _ownerNavItems(AppLocalizations l10n) => [
  NavItem(icon: Icons.dashboard_outlined, label: l10n.navOwnerOverview),
  NavItem(icon: Icons.apartment_outlined, label: l10n.navOwnerPgs),
  NavItem(icon: Icons.people_outline, label: l10n.navOwnerTenants),
  NavItem(icon: Icons.more_horiz, label: l10n.navMore),
];

List<NavItem> _managerNavItems(AppLocalizations l10n) => [
  NavItem(icon: Icons.today_outlined, label: l10n.navManagerToday),
  NavItem(icon: Icons.payments_outlined, label: l10n.navManagerPayments),
  NavItem(icon: Icons.grid_view_outlined, label: l10n.navManagerRooms),
  NavItem(icon: Icons.more_horiz, label: l10n.navMore),
];

List<NavItem> _tenantNavItems(AppLocalizations l10n) => [
  NavItem(icon: Icons.home_outlined, label: l10n.navTenantHome),
  NavItem(icon: Icons.receipt_long_outlined, label: l10n.navTenantRent),
  NavItem(icon: Icons.report_problem_outlined, label: l10n.navTenantComplaints),
  NavItem(icon: Icons.person_outline, label: l10n.navTenantProfile),
];

/// Bridges Riverpod's [authControllerProvider] into `go_router`'s
/// [Listenable]-based refresh mechanism, so a login/logout re-runs
/// [GoRouter.redirect] without any screen having to navigate manually.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AppUser?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
