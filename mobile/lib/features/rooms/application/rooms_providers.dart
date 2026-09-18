import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../data/mock_rooms_repository.dart';
import '../data/rooms_repository.dart';
import '../domain/room.dart';
import '../domain/sharing_type.dart';

/// The single override point for swapping the rooms data source: point this
/// at a Supabase-backed implementation in Phase 6.
final roomsRepositoryProvider = Provider<RoomsRepository>(
  (ref) => MockRoomsRepository(),
);

/// A property's rooms, grouped by floor. [MockRoomsRepository] holds its
/// state in memory, so a mutation followed by `ref.invalidate(roomsProvider(id))`
/// is enough to refetch the updated list — no separate notifier needed for
/// a single family-keyed read.
final roomsProvider = FutureProvider.family<List<Floor>, String>((
  ref,
  propertyId,
) async {
  final result = await ref
      .watch(roomsRepositoryProvider)
      .fetchFloors(propertyId);
  return result.when(ok: (floors) => floors, err: (failure) => throw failure);
});

/// The property an Owner is currently viewing on the Rooms screen.
final selectedPropertyIdProvider =
    NotifierProvider<SelectedPropertyIdNotifier, String>(
      SelectedPropertyIdNotifier.new,
    );

class SelectedPropertyIdNotifier extends Notifier<String> {
  @override
  String build() => 'hsr';

  void select(String propertyId) => state = propertyId;
}

Future<AppFailure?> addRoom(
  WidgetRef ref,
  String propertyId, {
  required String floor,
  required String number,
  required SharingType sharingType,
  required int rentPerBed,
}) async {
  final result = await ref
      .read(roomsRepositoryProvider)
      .addRoom(
        propertyId,
        floor: floor,
        number: number,
        sharingType: sharingType,
        rentPerBed: rentPerBed,
      );
  return result.when(
    ok: (_) {
      ref.invalidate(roomsProvider(propertyId));
      return null;
    },
    err: (failure) => failure,
  );
}
