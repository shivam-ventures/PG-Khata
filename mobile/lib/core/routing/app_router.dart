import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/account_menu_screen.dart';
import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/auth/presentation/phone_entry_screen.dart';
import '../../features/dashboard/presentation/manager/manager_today_screen.dart';
import '../../features/dashboard/presentation/owner/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/tenant/tenant_home_screen.dart';
import '../../shared/widgets/placeholder_screen.dart';
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

      if (user == null) {
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            RoleShell(navigationShell: shell, items: _ownerNavItems),
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
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Properties',
                  comingInPhase: 'Phase 1',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.ownerTenants,
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Tenants',
                  comingInPhase: 'Phase 1',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.ownerMore,
                builder: (context, state) => const AccountMenuScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            RoleShell(navigationShell: shell, items: _managerNavItems),
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
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Payments',
                  comingInPhase: 'Phase 3',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.managerRooms,
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Rooms',
                  comingInPhase: 'Phase 1',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.managerMore,
                builder: (context, state) => const AccountMenuScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            RoleShell(navigationShell: shell, items: _tenantNavItems),
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
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Rent',
                  comingInPhase: 'Phase 3',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.tenantComplaints,
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Complaints',
                  comingInPhase: 'Phase 5',
                ),
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
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text("That page doesn't exist: ${state.uri}")),
    ),
  );
});

const _ownerNavItems = [
  NavItem(icon: Icons.dashboard_outlined, label: 'Overview'),
  NavItem(icon: Icons.apartment_outlined, label: 'Properties'),
  NavItem(icon: Icons.people_outline, label: 'Tenants'),
  NavItem(icon: Icons.more_horiz, label: 'More'),
];

const _managerNavItems = [
  NavItem(icon: Icons.today_outlined, label: 'Today'),
  NavItem(icon: Icons.payments_outlined, label: 'Payments'),
  NavItem(icon: Icons.grid_view_outlined, label: 'Rooms'),
  NavItem(icon: Icons.more_horiz, label: 'More'),
];

const _tenantNavItems = [
  NavItem(icon: Icons.home_outlined, label: 'Home'),
  NavItem(icon: Icons.receipt_long_outlined, label: 'Rent'),
  NavItem(icon: Icons.report_problem_outlined, label: 'Complaints'),
  NavItem(icon: Icons.person_outline, label: 'Profile'),
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
