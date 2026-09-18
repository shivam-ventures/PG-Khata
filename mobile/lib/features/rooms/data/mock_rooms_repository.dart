import '../../../core/errors/result.dart';
import '../domain/bed.dart';
import '../domain/room.dart';
import '../domain/sharing_type.dart';
import 'rooms_repository.dart';

/// Phase-1 mock backing for [RoomsRepository]. Reconciles `Owner Rooms.dc.html`
/// and `Manager Rooms.dc.html`'s mock data into one consistent set per
/// property — the two design prototypes were built independently and each
/// only showed part of HSR PG's rooms; this merges them into floors so
/// every tenant name (Rahul Sharma/B-204, Ayesha Khan/A-108, ...) matches
/// what the dashboards already show.
class MockRoomsRepository implements RoomsRepository {
  final Map<String, List<Floor>> _floorsByProperty = {
    'hsr': [
      const Floor(
        name: 'Ground Floor',
        rooms: [
          Room(
            number: '101',
            floor: 'Ground Floor',
            sharingType: SharingType.triple,
            rentPerBed: 6500,
            beds: [
              Bed(label: 'A', tenantName: 'Ravi Kumar'),
              Bed(label: 'B', tenantName: 'Amit Shah'),
              Bed(label: 'C'),
            ],
          ),
          Room(
            number: '102',
            floor: 'Ground Floor',
            sharingType: SharingType.double_,
            rentPerBed: 7500,
            beds: [
              Bed(label: 'A', tenantName: 'Suresh Naik'),
              Bed(label: 'B', tenantName: 'Deepak Rao'),
            ],
          ),
        ],
      ),
      const Floor(
        name: 'First Floor',
        rooms: [
          Room(
            number: '201',
            floor: 'First Floor',
            sharingType: SharingType.triple,
            rentPerBed: 6500,
            beds: [
              Bed(label: 'A', tenantName: 'Manoj Patil'),
              Bed(label: 'B'),
              Bed(label: 'C'),
            ],
          ),
          Room(
            number: 'A-108',
            floor: 'First Floor',
            sharingType: SharingType.single,
            rentPerBed: 9000,
            beds: [Bed(label: 'A', tenantName: 'Ayesha Khan')],
          ),
        ],
      ),
      const Floor(
        name: 'Second Floor',
        rooms: [
          Room(
            number: 'B-204',
            floor: 'Second Floor',
            sharingType: SharingType.single,
            rentPerBed: 8500,
            beds: [Bed(label: 'A', tenantName: 'Rahul Sharma')],
          ),
        ],
      ),
      const Floor(
        name: 'Third Floor',
        rooms: [
          Room(
            number: 'C-301',
            floor: 'Third Floor',
            sharingType: SharingType.single,
            rentPerBed: 7500,
            beds: [Bed(label: 'A', tenantName: 'Vikram Rao')],
          ),
        ],
      ),
    ],
    'kor': [
      const Floor(
        name: 'Ground Floor',
        rooms: [
          Room(
            number: 'G1',
            floor: 'Ground Floor',
            sharingType: SharingType.double_,
            rentPerBed: 8000,
            beds: [
              Bed(label: 'A', tenantName: 'Vikas Gowda'),
              Bed(label: 'B', tenantName: 'Rahul Jain'),
            ],
          ),
        ],
      ),
    ],
    'ind': [
      const Floor(
        name: 'Ground Floor',
        rooms: [
          Room(
            number: 'G1',
            floor: 'Ground Floor',
            sharingType: SharingType.single,
            rentPerBed: 12000,
            beds: [Bed(label: 'A', tenantName: 'Priya Menon')],
          ),
        ],
      ),
    ],
  };

  @override
  Future<Result<List<Floor>>> fetchFloors(String propertyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return Ok(List.unmodifiable(_floorsByProperty[propertyId] ?? const []));
  }

  @override
  Future<Result<Room>> addRoom(
    String propertyId, {
    required String floor,
    required String number,
    required SharingType sharingType,
    required int rentPerBed,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final room = Room(
      number: number,
      floor: floor,
      sharingType: sharingType,
      rentPerBed: rentPerBed,
      beds: [
        for (var i = 0; i < sharingType.bedCount; i++)
          Bed(label: String.fromCharCode(65 + i)),
      ],
    );
    final floors = List<Floor>.from(_floorsByProperty[propertyId] ?? const []);
    final floorIndex = floors.indexWhere((f) => f.name == floor);
    if (floorIndex == -1) {
      floors.add(Floor(name: floor, rooms: [room]));
    } else {
      floors[floorIndex] = Floor(
        name: floor,
        rooms: [...floors[floorIndex].rooms, room],
      );
    }
    _floorsByProperty[propertyId] = floors;
    return Ok(room);
  }
}
