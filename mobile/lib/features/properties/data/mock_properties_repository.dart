import '../../../core/errors/result.dart';
import '../domain/org_manager.dart';
import '../domain/property.dart';
import 'properties_repository.dart';

/// Mock backing for [PropertiesRepository], for isolated UI dev/tests —
/// superseded by [SupabasePropertiesRepository] as the default. Seeded from
/// `Properties.dc.html`'s own mock data. Holds its state in memory for the
/// life of the app (this instance is cached by Riverpod) — mutations aren't
/// persisted across restarts, which is expected for a mock.
class MockPropertiesRepository implements PropertiesRepository {
  final List<Property> _properties = [
    const Property(
      id: 'hsr',
      name: 'HSR PG',
      address: '27th Main, HSR Layout, Bengaluru',
      totalBeds: 20,
      managerName: 'Ramesh K.',
    ),
    const Property(
      id: 'kor',
      name: 'Koramangala PG',
      address: '5th Block, Koramangala, Bengaluru',
      totalBeds: 18,
      managerName: 'Divya S.',
    ),
    const Property(
      id: 'ind',
      name: 'Indiranagar PG',
      address: '100ft Road, Indiranagar, Bengaluru',
      totalBeds: 11,
      managerName: 'Ramesh K.',
    ),
  ];

  final List<OrgManager> _managers = [
    const OrgManager(id: 'm1', name: 'Ramesh K.', phone: '9876500000'),
    const OrgManager(id: 'm2', name: 'Divya S.', phone: '9876511111'),
  ];

  @override
  Future<Result<List<Property>>> fetchProperties() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return Ok(List.unmodifiable(_properties));
  }

  @override
  Future<Result<Property>> addProperty({
    required String name,
    required String address,
    required int totalBeds,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final property = Property(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      address: address,
      totalBeds: totalBeds,
      managerName: 'Unassigned',
    );
    _properties.add(property);
    return Ok(property);
  }

  @override
  Future<Result<Property>> updateProperty(
    String id, {
    required String name,
    required String address,
    required int totalBeds,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _properties.indexWhere((p) => p.id == id);
    final updated = _properties[index].copyWith(
      name: name,
      address: address,
      totalBeds: totalBeds,
    );
    _properties[index] = updated;
    return Ok(updated);
  }

  @override
  Future<Result<List<OrgManager>>> fetchOrgManagers() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return Ok(List.unmodifiable(_managers));
  }

  @override
  Future<Result<void>> assignExistingManager(
    String propertyId,
    String managerId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final manager = _managers.firstWhere((m) => m.id == managerId);
    final index = _properties.indexWhere((p) => p.id == propertyId);
    _properties[index] = _properties[index].copyWith(
      managerName: manager.name,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> inviteAndAssignManager(
    String propertyId, {
    required String name,
    required String phone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final manager = OrgManager(
      id: 'm${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      phone: phone,
    );
    _managers.add(manager);
    final index = _properties.indexWhere((p) => p.id == propertyId);
    _properties[index] = _properties[index].copyWith(managerName: name);
    return const Ok(null);
  }

  @override
  Future<Result<void>> unassignManager(
    String propertyId,
    String managerId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _properties.indexWhere((p) => p.id == propertyId);
    _properties[index] = _properties[index].copyWith(
      managerName: 'Unassigned',
    );
    return const Ok(null);
  }
}
