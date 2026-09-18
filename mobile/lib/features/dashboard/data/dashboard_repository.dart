import '../../../core/errors/result.dart';
import '../domain/manager_today_data.dart';
import '../domain/owner_dashboard_data.dart';
import '../domain/tenant_home_data.dart';

/// Read-only dashboard data for each role's home screen.
/// [MockDashboardRepository] backs this in Phase 0; a Supabase-backed
/// implementation (querying properties/tenants/payments/complaints
/// directly) replaces it in Phase 6 behind the same interface.
abstract interface class DashboardRepository {
  Future<Result<OwnerDashboardData>> fetchOwnerDashboard();

  Future<Result<ManagerTodayData>> fetchManagerToday({required String pgId});

  Future<Result<TenantHomeData>> fetchTenantHome();
}
