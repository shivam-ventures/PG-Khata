import '../../../core/errors/result.dart';
import '../domain/room.dart';
import '../domain/sharing_type.dart';

/// Room/bed occupancy for one property. [MockRoomsRepository] backs this in
/// Phase 1; a Supabase-backed implementation replaces it in Phase 6 behind
/// the same interface.
abstract interface class RoomsRepository {
  Future<Result<List<Floor>>> fetchFloors(String propertyId);

  Future<Result<Room>> addRoom(
    String propertyId, {
    required String floor,
    required String number,
    required SharingType sharingType,
    required int rentPerBed,
  });

  /// Fills a vacant bed with [tenantName] — used once a tenant record is
  /// actually created (staff Add Tenant, or an invite-link join completing)
  /// so Rooms and Tenants never drift apart on who occupies what.
  Future<Result<void>> occupyBed(
    String propertyId, {
    required String room,
    required String bed,
    required String tenantName,
  });
}
