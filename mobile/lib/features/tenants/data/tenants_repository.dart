import '../../../core/errors/result.dart';
import '../domain/tenant_record.dart';
import '../domain/tenant_status.dart';

/// Tenant roster + pending-assignment CRUD. [MockTenantsRepository] backs
/// this in Phase 1; a Supabase-backed implementation replaces it in
/// Phase 6 behind the same interface.
abstract interface class TenantsRepository {
  /// All tenants, or only those at [propertyId] when given — the Owner
  /// roster spans the portfolio, the Manager roster is scoped to one PG.
  Future<Result<List<TenantRecord>>> fetchTenants({String? propertyId});

  Future<Result<List<PendingTenant>>> fetchPendingTenants({String? propertyId});

  Future<Result<TenantRecord>> addTenant({
    required String name,
    required String phone,
    required String propertyId,
    required String propertyName,
    required String roomBed,
    required int rent,
    required DateTime joinedDate,
    required TenantStatus status,
  });

  /// Turns a [PendingTenant] into a real [TenantRecord] once staff assigns
  /// a bed and rent.
  Future<Result<TenantRecord>> assignPendingTenant(
    String pendingId, {
    required String roomBed,
    required int rent,
    required DateTime joinedDate,
  });

  Future<Result<TenantRecord>> moveOutTenant(String tenantId);
}
