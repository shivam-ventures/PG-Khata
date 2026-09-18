import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../data/dashboard_repository.dart';
import '../data/mock_dashboard_repository.dart';
import '../domain/manager_today_data.dart';
import '../domain/owner_dashboard_data.dart';
import '../domain/tenant_home_data.dart';

/// The single override point for swapping the dashboard data source: point
/// this at a Supabase-backed implementation in Phase 6.
final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => MockDashboardRepository(),
);

final ownerDashboardProvider = FutureProvider<OwnerDashboardData>((ref) async {
  final result = await ref
      .watch(dashboardRepositoryProvider)
      .fetchOwnerDashboard();
  return result.when(ok: (data) => data, err: (failure) => throw failure);
});

/// The PG a Manager is currently viewing — mirrors the design's `?pg=`
/// query param, as real, testable state instead of a URL hack (see
/// `docs/architecture.md`'s routing section).
final managerSelectedPgIdProvider =
    NotifierProvider<ManagerSelectedPgIdNotifier, String>(
      ManagerSelectedPgIdNotifier.new,
    );

class ManagerSelectedPgIdNotifier extends Notifier<String> {
  @override
  String build() => 'hsr';

  void select(String pgId) => state = pgId;
}

final managerTodayProvider = FutureProvider<ManagerTodayData>((ref) async {
  final pgId = ref.watch(managerSelectedPgIdProvider);
  final result = await ref
      .watch(dashboardRepositoryProvider)
      .fetchManagerToday(pgId: pgId);
  return result.when(ok: (data) => data, err: (failure) => throw failure);
});

final tenantHomeProvider = FutureProvider<TenantHomeData>((ref) async {
  final result = await ref.watch(dashboardRepositoryProvider).fetchTenantHome();
  return result.when(ok: (data) => data, err: (failure) => throw failure);
});
