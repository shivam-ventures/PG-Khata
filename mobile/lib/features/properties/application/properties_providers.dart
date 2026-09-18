import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../data/mock_properties_repository.dart';
import '../data/properties_repository.dart';
import '../domain/property.dart';

/// The single override point for swapping the properties data source: point
/// this at a Supabase-backed implementation in Phase 6.
final propertiesRepositoryProvider = Provider<PropertiesRepository>(
  (ref) => MockPropertiesRepository(),
);

final propertiesProvider =
    AsyncNotifierProvider<PropertiesController, List<Property>>(
      PropertiesController.new,
    );

class PropertiesController extends AsyncNotifier<List<Property>> {
  @override
  Future<List<Property>> build() async {
    final result = await ref
        .watch(propertiesRepositoryProvider)
        .fetchProperties();
    return result.when(
      ok: (properties) => properties,
      err: (failure) => throw failure,
    );
  }

  Future<AppFailure?> addProperty({
    required String name,
    required String address,
    required int totalBeds,
    required String managerName,
  }) async {
    final result = await ref
        .read(propertiesRepositoryProvider)
        .addProperty(
          name: name,
          address: address,
          totalBeds: totalBeds,
          managerName: managerName,
        );
    return result.when(
      ok: (property) {
        state = AsyncValue.data([...state.requireValue, property]);
        return null;
      },
      err: (failure) => failure,
    );
  }

  Future<AppFailure?> updateProperty(
    String id, {
    required String name,
    required String address,
    required int totalBeds,
    required String managerName,
  }) async {
    final result = await ref
        .read(propertiesRepositoryProvider)
        .updateProperty(
          id,
          name: name,
          address: address,
          totalBeds: totalBeds,
          managerName: managerName,
        );
    return result.when(
      ok: (updated) {
        state = AsyncValue.data([
          for (final property in state.requireValue)
            if (property.id == id) updated else property,
        ]);
        return null;
      },
      err: (failure) => failure,
    );
  }
}
