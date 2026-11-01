import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/bed.dart';
import '../domain/room.dart';
import '../domain/sharing_type.dart';
import 'rooms_repository.dart';

/// Real backend for [RoomsRepository]. Bed occupancy is never stored — it's
/// read from the `bed_occupancy` view (derived live from `tenancies`, see
/// `docs/backend-domain-model.md` §6), joined client-side rather than via a
/// single PostgREST embed since a view has no declared foreign keys for
/// PostgREST to auto-detect.
class SupabaseRoomsRepository implements RoomsRepository {
  SupabaseRoomsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<Floor>>> fetchFloors(String propertyId) async {
    // A blank id shows up briefly for a Manager whose real assigned
    // property hasn't loaded yet (see managerSelectedPgIdProvider) — treat
    // it as "nothing to show" rather than sending an empty string where
    // Postgres expects a uuid, which would fail the cast.
    if (propertyId.isEmpty) return const Ok([]);
    try {
      final roomRows = await _client
          .from('rooms')
          .select('id, floor_label, room_number, sharing_type, rent_per_bed')
          .eq('property_id', propertyId)
          .filter('archived_at', 'is', null)
          .order('floor_label')
          .order('room_number');
      if (roomRows.isEmpty) return const Ok([]);

      final roomIds = [for (final r in roomRows) r['id'] as String];
      final bedRows = await _client
          .from('beds')
          .select('id, room_id, label')
          .inFilter('room_id', roomIds)
          .filter('archived_at', 'is', null)
          .order('label');

      final bedIds = [for (final b in bedRows) b['id'] as String];
      final occupancyRows = bedIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _client
                .from('bed_occupancy')
                .select('bed_id, active_tenant_profile_id')
                .inFilter('bed_id', bedIds);
      final tenantProfileIdByBed = {
        for (final o in occupancyRows)
          o['bed_id'] as String: o['active_tenant_profile_id'] as String?,
      };

      final tenantProfileIds = tenantProfileIdByBed.values
          .whereType<String>()
          .toSet()
          .toList();
      final nameByProfileId = <String, String>{};
      if (tenantProfileIds.isNotEmpty) {
        final profileRows = await _client
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', tenantProfileIds);
        for (final p in profileRows) {
          nameByProfileId[p['id'] as String] = p['full_name'] as String;
        }
      }

      final bedsByRoomId = <String, List<Bed>>{};
      for (final bedRow in bedRows) {
        final roomId = bedRow['room_id'] as String;
        final tenantProfileId = tenantProfileIdByBed[bedRow['id'] as String];
        (bedsByRoomId[roomId] ??= []).add(
          Bed(
            id: bedRow['id'] as String,
            label: bedRow['label'] as String,
            tenantName: tenantProfileId == null
                ? null
                : nameByProfileId[tenantProfileId],
          ),
        );
      }

      final roomsByFloor = <String, List<Room>>{};
      for (final roomRow in roomRows) {
        final floorLabel = roomRow['floor_label'] as String;
        (roomsByFloor[floorLabel] ??= []).add(
          Room(
            number: roomRow['room_number'] as String,
            floor: floorLabel,
            sharingType: _sharingTypeFromDb(roomRow['sharing_type'] as String),
            rentPerBed: (roomRow['rent_per_bed'] as num).round(),
            beds: bedsByRoomId[roomRow['id'] as String] ?? const [],
          ),
        );
      }

      return Ok([
        for (final entry in roomsByFloor.entries)
          Floor(name: entry.key, rooms: entry.value),
      ]);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<Room>> addRoom(
    String propertyId, {
    required String floor,
    required String number,
    required SharingType sharingType,
    required int rentPerBed,
  }) async {
    try {
      final roomRow = await _client
          .from('rooms')
          .insert({
            'property_id': propertyId,
            'floor_label': floor,
            'room_number': number,
            'sharing_type': _sharingTypeToDb(sharingType),
            'rent_per_bed': rentPerBed,
          })
          .select('id')
          .single();
      final roomId = roomRow['id'] as String;

      final bedLabels = [
        for (var i = 0; i < sharingType.bedCount; i++)
          String.fromCharCode(65 + i),
      ];
      final bedRows = await _client
          .from('beds')
          .insert([
            for (final label in bedLabels)
              {'room_id': roomId, 'label': label},
          ])
          .select('id, label');

      return Ok(
        Room(
          number: number,
          floor: floor,
          sharingType: sharingType,
          rentPerBed: rentPerBed,
          beds: [
            for (final row in bedRows)
              Bed(id: row['id'] as String, label: row['label'] as String),
          ],
        ),
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return const Err(RoomNumberTakenFailure());
      }
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> occupyBed(
    String propertyId, {
    required String room,
    required String bed,
    required String tenantName,
  }) async {
    // Deliberate no-op: the real schema has no bed "occupied" column to
    // write (docs/backend-domain-model.md §6) — occupancy is always derived
    // from an actual `tenancies` row. This method exists only so the
    // still-mock onboarding join-invite flow (features/onboarding) keeps
    // compiling against the shared [RoomsRepository] interface; once that
    // flow is wired to the real `create_tenancy`-style RPC, both this
    // method and its call site should be deleted rather than implemented.
    return const Ok(null);
  }

  String _sharingTypeToDb(SharingType type) => switch (type) {
    SharingType.single => 'single',
    SharingType.double_ => 'double',
    SharingType.triple => 'triple',
    SharingType.four => 'four',
  };

  SharingType _sharingTypeFromDb(String value) => switch (value) {
    'single' => SharingType.single,
    'double' => SharingType.double_,
    'triple' => SharingType.triple,
    'four' => SharingType.four,
    _ => throw StateError('Unknown sharing_type from database: $value'),
  };
}
