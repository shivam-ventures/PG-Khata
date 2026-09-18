import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../data/mock_tenants_repository.dart';
import '../data/tenants_repository.dart';
import '../domain/tenant_record.dart';
import '../domain/tenant_status.dart';

/// The single override point for swapping the tenants data source: point
/// this at a Supabase-backed implementation in Phase 6.
final tenantsRepositoryProvider = Provider<TenantsRepository>(
  (ref) => MockTenantsRepository(),
);

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
}) async {
  final result = await ref
      .read(tenantsRepositoryProvider)
      .assignPendingTenant(
        pendingId,
        roomBed: roomBed,
        rent: rent,
        joinedDate: joinedDate,
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
