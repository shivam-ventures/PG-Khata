import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../data/mock_tenants_repository.dart';
import '../data/tenants_repository.dart';
import '../domain/tenant_record.dart';
import '../domain/tenant_status.dart';

/// The single override point for swapping the tenants data source: point
/// this at a Supabase-backed implementation in Phase 6.
final tenantsRepositoryProvider = Provider<TenantsRepository>(
  (ref) => MockTenantsRepository(),
);

/// Digits only, last 10 — so "+91 98222 33445" (how the roster stores a
/// phone) and "9822233445" (how a login field or an invite link's typed
/// number stores it) compare equal regardless of formatting.
String _normalizedPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length <= 10 ? digits : digits.substring(digits.length - 10);
}

/// Resolves the signed-in Tenant's own [TenantRecord] by matching phone
/// numbers against the roster — the mock-era stand-in for a real backend's
/// user-to-tenant foreign key (Phase 6 replaces this with a real join, but
/// the *shape* — "a tenant screen reads its own record, never a constant"
/// — is the thing that has to be right before then). Null means the
/// signed-in phone has no assigned bed yet: a brand-new login, or a demo
/// number nobody added as a tenant.
final currentTenantRecordProvider = FutureProvider<TenantRecord?>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null || user.role != UserRole.tenant) return null;

  final tenants = await ref.watch(tenantsProvider(null).future);
  final userPhone = _normalizedPhone(user.phone);
  for (final tenant in tenants) {
    if (_normalizedPhone(tenant.phone) == userPhone) return tenant;
  }
  return null;
});

/// The tenant roster — `null` for the Owner's whole-portfolio view, a
/// property id for the Manager's PG-scoped view.
final tenantsProvider = FutureProvider.family<List<TenantRecord>, String?>((
  ref,
  propertyId,
) async {
  final result = await ref
      .watch(tenantsRepositoryProvider)
      .fetchTenants(propertyId: propertyId);
  return result.when(ok: (tenants) => tenants, err: (failure) => throw failure);
});

final pendingTenantsProvider =
    FutureProvider.family<List<PendingTenant>, String?>((
      ref,
      propertyId,
    ) async {
      final result = await ref
          .watch(tenantsRepositoryProvider)
          .fetchPendingTenants(propertyId: propertyId);
      return result.when(
        ok: (pending) => pending,
        err: (failure) => throw failure,
      );
    });

/// Refreshes both the whole-portfolio and per-property cached reads after a
/// mutation, since [MockTenantsRepository] holds its state in memory rather
/// than each family entry owning its own.
void _invalidateTenantLists(WidgetRef ref, String propertyId) {
  ref.invalidate(tenantsProvider(null));
  ref.invalidate(tenantsProvider(propertyId));
  ref.invalidate(pendingTenantsProvider(null));
  ref.invalidate(pendingTenantsProvider(propertyId));
}

Future<AppFailure?> addTenant(
  WidgetRef ref, {
  required String name,
  required String phone,
  required String propertyId,
  required String propertyName,
  required String roomBed,
  required int rent,
  required DateTime joinedDate,
  required TenantStatus status,
  int? depositAmount,
}) async {
  final result = await ref
      .read(tenantsRepositoryProvider)
      .addTenant(
        name: name,
        phone: phone,
        propertyId: propertyId,
        propertyName: propertyName,
        roomBed: roomBed,
        rent: rent,
        joinedDate: joinedDate,
        status: status,
        depositAmount: depositAmount,
      );
  return result.when(
    ok: (_) {
      _invalidateTenantLists(ref, propertyId);
      return null;
    },
    err: (failure) => failure,
  );
}

Future<AppFailure?> assignPendingTenant(
  WidgetRef ref,
  String pendingId, {
  required String propertyId,
  required String roomBed,
  required int rent,
  required DateTime joinedDate,
  int? depositAmount,
}) async {
  final result = await ref
      .read(tenantsRepositoryProvider)
      .assignPendingTenant(
        pendingId,
        roomBed: roomBed,
        rent: rent,
        joinedDate: joinedDate,
        depositAmount: depositAmount,
      );
  return result.when(
    ok: (_) {
      _invalidateTenantLists(ref, propertyId);
      return null;
    },
    err: (failure) => failure,
  );
}

Future<AppFailure?> moveOutTenant(
  WidgetRef ref,
  String tenantId, {
  required String propertyId,
}) async {
  final result = await ref
      .read(tenantsRepositoryProvider)
      .moveOutTenant(tenantId);
  return result.when(
    ok: (_) {
      _invalidateTenantLists(ref, propertyId);
      return null;
    },
    err: (failure) => failure,
  );
}
