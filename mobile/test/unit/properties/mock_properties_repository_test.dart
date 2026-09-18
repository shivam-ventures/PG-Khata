import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/result.dart';
import 'package:pg_khata/features/properties/data/mock_properties_repository.dart';

void main() {
  late MockPropertiesRepository repository;

  setUp(() => repository = MockPropertiesRepository());

  test('fetchProperties returns the seeded portfolio', () async {
    final result = await repository.fetchProperties();
    final properties = result.when(ok: (p) => p, err: (_) => null);
    expect(properties, isNotNull);
    expect(properties!.length, 3);
    expect(properties.map((p) => p.id), containsAll(['hsr', 'kor', 'ind']));
  });

  test('addProperty appends a new property with zero occupancy', () async {
    final result = await repository.addProperty(
      name: 'New PG',
      address: 'Some address',
      totalBeds: 10,
      managerName: 'Unassigned',
    );
    final added = result.when(ok: (p) => p, err: (_) => null);
    expect(added, isNotNull);
    expect(added!.occupiedBeds, 0);

    final all = (await repository.fetchProperties()).when(
      ok: (p) => p,
      err: (_) => null,
    );
    expect(all, isNotNull);
    expect(all!.length, 4);
  });

  test('updateProperty changes the matching property in place', () async {
    final result = await repository.updateProperty(
      'hsr',
      name: 'HSR PG (renamed)',
      address: 'New address',
      totalBeds: 25,
      managerName: 'Divya S.',
    );
    final updated = result.when(ok: (p) => p, err: (_) => null);
    expect(updated, isNotNull);
    expect(updated!.name, 'HSR PG (renamed)');
    expect(updated.totalBeds, 25);
    // occupiedBeds carries over rather than resetting on an edit.
    expect(updated.occupiedBeds, 18);
  });
}
