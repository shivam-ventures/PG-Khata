import '../../../core/errors/result.dart';
import '../domain/tenant_record.dart';
import '../domain/tenant_status.dart';
import 'tenants_repository.dart';

const _propertyNames = {
  'hsr': 'HSR PG',
  'kor': 'Koramangala PG',
  'ind': 'Indiranagar PG',
};

/// Phase-1 mock backing for [TenantsRepository]. Reconciles `Owner
/// Tenants.dc.html` and `Manager Tenants.dc.html`'s mock data (each showed
/// a different subset) into one roster consistent with [MockRoomsRepository]'s
/// bed occupants.
class MockTenantsRepository implements TenantsRepository {
  final List<TenantRecord> _tenants = [
    TenantRecord(
      id: 't1',
      name: 'Ravi Kumar',
      phone: '+91 98765 43210',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      roomBed: '101 - A',
      rent: 6500,
      joinedDate: DateTime(2025, 6, 1),
      status: TenantStatus.active,
    ),
    TenantRecord(
      id: 't2',
      name: 'Amit Shah',
      phone: '+91 98765 11122',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      roomBed: '101 - B',
      rent: 6500,
      joinedDate: DateTime(2025, 7, 15),
      status: TenantStatus.active,
    ),
    TenantRecord(
      id: 't3',
      name: 'Suresh Naik',
      phone: '+91 90000 22233',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      roomBed: '102 - A',
      rent: 7500,
      joinedDate: DateTime(2024, 11, 10),
      status: TenantStatus.noticePeriod,
    ),
    TenantRecord(
      id: 't4',
      name: 'Deepak Rao',
      phone: '+91 90000 33344',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      roomBed: '102 - B',
      rent: 7500,
      joinedDate: DateTime(2025, 3, 1),
      status: TenantStatus.active,
    ),
    TenantRecord(
      id: 't5',
      name: 'Manoj Patil',
      phone: '+91 90000 44455',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      roomBed: '201 - A',
      rent: 6500,
      joinedDate: DateTime(2025, 5, 20),
      status: TenantStatus.active,
    ),
    TenantRecord(
      id: 't6',
      name: 'Ayesha Khan',
      phone: '+91 98111 22334',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      roomBed: 'A-108 - A',
      rent: 9000,
      joinedDate: DateTime(2025, 8, 1),
      status: TenantStatus.active,
    ),
    TenantRecord(
      id: 't7',
      name: 'Rahul Sharma',
      phone: '+91 98222 33445',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      roomBed: 'B-204 - A',
      rent: 8500,
      joinedDate: DateTime(2025, 4, 12),
      status: TenantStatus.active,
    ),
    TenantRecord(
      id: 't8',
      name: 'Vikram Rao',
      phone: '+91 98333 44556',
      propertyId: 'hsr',
      propertyName: _propertyNames['hsr']!,
      roomBed: 'C-301 - A',
      rent: 7500,
      joinedDate: DateTime(2025, 2, 1),
      status: TenantStatus.noticePeriod,
    ),
    TenantRecord(
      id: 't9',
      name: 'Vikas Gowda',
      phone: '+91 99887 77661',
      propertyId: 'kor',
      propertyName: _propertyNames['kor']!,
      roomBed: 'G1 - A',
      rent: 8000,
      joinedDate: DateTime(2025, 2, 20),
      status: TenantStatus.active,
    ),
    TenantRecord(
      id: 't10',
      name: 'Rahul Jain',
      phone: '+91 99887 88772',
      propertyId: 'kor',
      propertyName: _propertyNames['kor']!,
      roomBed: 'G1 - B',
      rent: 8000,
      joinedDate: DateTime(2025, 3, 10),
      status: TenantStatus.active,
    ),
    TenantRecord(
      id: 't11',
      name: 'Priya Menon',
      phone: '+91 98123 45566',
      propertyId: 'ind',
      propertyName: _propertyNames['ind']!,
      roomBed: 'G1 - A',
      rent: 12000,
      joinedDate: DateTime(2025, 1, 5),
      status: TenantStatus.active,
    ),
  ];

  final List<PendingTenant> _pending = [
    const PendingTenant(
      id: 'p1',
      name: 'Karthik Iyer',
      phone: '+91 90112 33445',
      propertyId: 'hsr',
      propertyName: 'HSR PG',
    ),
  ];

  @override
  Future<Result<List<TenantRecord>>> fetchTenants({String? propertyId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final tenants = propertyId == null
        ? _tenants
        : _tenants.where((t) => t.propertyId == propertyId).toList();
    return Ok(List.unmodifiable(tenants));
  }

  @override
  Future<Result<List<PendingTenant>>> fetchPendingTenants({
    String? propertyId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final pending = propertyId == null
        ? _pending
        : _pending.where((p) => p.propertyId == propertyId).toList();
    return Ok(List.unmodifiable(pending));
  }

  @override
  Future<Result<TenantRecord>> addTenant({
    required String name,
    required String phone,
    required String propertyId,
    required String propertyName,
    required String roomBed,
    required int rent,
    required DateTime joinedDate,
    required TenantStatus status,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final tenant = TenantRecord(
      id: 't${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      phone: phone,
      propertyId: propertyId,
      propertyName: propertyName,
      roomBed: roomBed,
      rent: rent,
      joinedDate: joinedDate,
      status: status,
    );
    _tenants.add(tenant);
    return Ok(tenant);
  }

  @override
  Future<Result<TenantRecord>> assignPendingTenant(
    String pendingId, {
    required String roomBed,
    required int rent,
    required DateTime joinedDate,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final pending = _pending.firstWhere((p) => p.id == pendingId);
    final tenant = TenantRecord(
      id: 't${DateTime.now().microsecondsSinceEpoch}',
      name: pending.name,
      phone: pending.phone,
      propertyId: pending.propertyId,
      propertyName: pending.propertyName,
      roomBed: roomBed,
      rent: rent,
      joinedDate: joinedDate,
      status: TenantStatus.active,
    );
    _tenants.add(tenant);
    _pending.removeWhere((p) => p.id == pendingId);
    return Ok(tenant);
  }

  @override
  Future<Result<TenantRecord>> moveOutTenant(String tenantId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _tenants.indexWhere((t) => t.id == tenantId);
    final updated = _tenants[index].copyWith(
      status: TenantStatus.vacated,
      roomBed: '${_tenants[index].roomBed} (freed)',
    );
    _tenants[index] = updated;
    return Ok(updated);
  }
}
