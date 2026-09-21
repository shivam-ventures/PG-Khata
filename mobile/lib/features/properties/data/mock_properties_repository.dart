import '../../../core/errors/result.dart';
import '../domain/property.dart';
import 'properties_repository.dart';

/// Phase-1 mock backing for [PropertiesRepository]. Seeded from
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
    required String managerName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final property = Property(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      address: address,
      totalBeds: totalBeds,
      managerName: managerName,
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
    required String managerName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _properties.indexWhere((p) => p.id == id);
    final updated = _properties[index].copyWith(
      name: name,
      address: address,
      totalBeds: totalBeds,
      managerName: managerName,
    );
    _properties[index] = updated;
    return Ok(updated);
  }
}
