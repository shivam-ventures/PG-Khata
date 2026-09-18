import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/result.dart';
import 'package:pg_khata/features/tenants/data/mock_tenants_repository.dart';
import 'package:pg_khata/features/tenants/domain/tenant_status.dart';

void main() {
  late MockTenantsRepository repository;

  setUp(() => repository = MockTenantsRepository());

  test('fetchTenants(propertyId: null) returns the whole portfolio', () async {
    final result = await repository.fetchTenants();
    final tenants = result.when(ok: (t) => t, err: (_) => null);
    expect(tenants, isNotNull);
    expect(tenants!.length, 11);
  });

  test('fetchTenants scoped to one property matches its room roster', () async {
    final result = await repository.fetchTenants(propertyId: 'kor');
    final tenants = result.when(ok: (t) => t, err: (_) => null);
    expect(tenants, isNotNull);
    expect(
      tenants!.map((t) => t.name),
      containsAll(['Vikas Gowda', 'Rahul Jain']),
    );
    expect(tenants.every((t) => t.propertyId == 'kor'), isTrue);
  });

  test(
    'assignPendingTenant turns a pending record into a real tenant',
    () async {
      final before = (await repository.fetchPendingTenants(propertyId: 'hsr'))
          .when(ok: (p) => p, err: (_) => null)!;
      expect(before, isNotEmpty);
      final pendingId = before.first.id;

      final result = await repository.assignPendingTenant(
        pendingId,
        roomBed: '301 - A',
        rent: 7000,
        joinedDate: DateTime(2026, 1, 1),
      );
      final assigned = result.when(ok: (t) => t, err: (_) => null);
      expect(assigned, isNotNull);
      expect(assigned!.status, TenantStatus.active);
      expect(assigned.roomBed, '301 - A');

      final afterPending = (await repository.fetchPendingTenants(
        propertyId: 'hsr',
      )).when(ok: (p) => p, err: (_) => null)!;
      expect(afterPending.map((p) => p.id), isNot(contains(pendingId)));
    },
  );

  test(
    'moveOutTenant sets status to vacated and marks the bed freed',
    () async {
      final all = (await repository.fetchTenants()).when(
        ok: (t) => t,
        err: (_) => null,
      )!;
      final tenant = all.first;

      final result = await repository.moveOutTenant(tenant.id);
      final moved = result.when(ok: (t) => t, err: (_) => null);
      expect(moved, isNotNull);
      expect(moved!.status, TenantStatus.vacated);
      expect(moved.roomBed, contains('(freed)'));
      expect(moved.canMoveOut, isFalse);
    },
  );
}
