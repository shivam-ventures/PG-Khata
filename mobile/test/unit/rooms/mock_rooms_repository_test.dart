import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/result.dart';
import 'package:pg_khata/features/rooms/data/mock_rooms_repository.dart';
import 'package:pg_khata/features/rooms/domain/sharing_type.dart';

void main() {
  late MockRoomsRepository repository;

  setUp(() => repository = MockRoomsRepository());

  test(
    'fetchFloors reconciles Owner and Manager Rooms mock data for HSR',
    () async {
      final result = await repository.fetchFloors('hsr');
      final floors = result.when(ok: (f) => f, err: (_) => null);
      expect(floors, isNotNull);

      final allRooms = [for (final floor in floors!) ...floor.rooms];
      final roomNumbers = allRooms.map((r) => r.number).toSet();
      // From Owner Rooms.dc.html.
      expect(roomNumbers, containsAll(['101', '102', '201']));
      // From Manager Rooms.dc.html — merged in so every screen agrees.
      expect(roomNumbers, containsAll(['A-108', 'B-204', 'C-301']));
    },
  );

  test('a room with any vacant bed reports hasVacantBed', () async {
    final floors = (await repository.fetchFloors('hsr'))
        .when(ok: (f) => f, err: (_) => null)!;
    final room101 = floors
        .expand((f) => f.rooms)
        .firstWhere((r) => r.number == '101');
    expect(room101.hasVacantBed, isTrue); // Bed C is vacant

    final room102 = floors
        .expand((f) => f.rooms)
        .firstWhere((r) => r.number == '102');
    expect(room102.hasVacantBed, isFalse); // both beds occupied
  });

  test(
    'addRoom creates the right number of beds for the sharing type',
    () async {
      final result = await repository.addRoom(
        'hsr',
        floor: 'Ground Floor',
        number: '103',
        sharingType: SharingType.four,
        rentPerBed: 5000,
      );
      final room = result.when(ok: (r) => r, err: (_) => null);
      expect(room, isNotNull);
      expect(room!.beds.length, 4);
      expect(room.beds.every((bed) => bed.isVacant), isTrue);

      final floors = (await repository.fetchFloors('hsr'))
          .when(ok: (f) => f, err: (_) => null)!;
      final groundFloor = floors.firstWhere((f) => f.name == 'Ground Floor');
      expect(groundFloor.rooms.map((r) => r.number), contains('103'));
    },
  );
}
