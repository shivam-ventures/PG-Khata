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
    int? depositAmount,
  });

  /// Turns a [PendingTenant] into a real [TenantRecord] once staff assigns
  /// a bed and rent.
  Future<Result<TenantRecord>> assignPendingTenant(
    String pendingId, {
    required String roomBed,
    required int rent,
    required DateTime joinedDate,
    int? depositAmount,
  });

  /// The immediate, no-notice move-out — unchanged by the notice-period
  /// flow below; a zero-notice move-out forfeits the deposit by the same
  /// rule any other short notice does.
  Future<Result<TenantRecord>> moveOutTenant(String tenantId);

  /// Puts an active tenancy into [TenantStatus.noticePeriod]. Fewer than 15
  /// days' notice fails with [ShortNoticeFailure] unless
  /// [acknowledgeForfeiture] is true, in which case it succeeds with the
  /// deposit marked forfeited — see `evaluate_move_out_notice` on the
  /// backend for the single place this policy lives.
  Future<Result<TenantRecord>> requestMoveOut(
    String tenantId, {
    required DateTime moveOutDate,
    bool acknowledgeForfeiture = false,
  });

  /// Reverts a [TenantStatus.noticePeriod] tenancy back to active — the
  /// tenant changed their mind, or staff recorded the notice in error.
  Future<Result<TenantRecord>> cancelMoveOutNotice(String tenantId);

  /// Staff confirming a pending (or previously forfeited/returned, as an
  /// override) deposit was actually handed back outside the app — this
  /// never moves real money itself, only records that it happened.
  Future<Result<TenantRecord>> markDepositReturned(String tenantId);
}
