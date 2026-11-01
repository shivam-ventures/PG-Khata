import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../complaints/application/complaints_providers.dart';
import '../../complaints/domain/complaint_status.dart';
import '../../payments/application/payments_providers.dart';
import '../../payments/domain/payment_status.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../rooms/application/rooms_providers.dart';
import '../data/properties_repository.dart';
import '../data/supabase_properties_repository.dart';
import '../domain/org_manager.dart';
import '../domain/property.dart';
import '../domain/property_metrics.dart';

/// The single override point for swapping the properties data source — was
/// `MockPropertiesRepository()` through Phase 1; now backed by real
/// Supabase-scoped-by-RLS rows.
final propertiesRepositoryProvider = Provider<PropertiesRepository>(
  (ref) => SupabasePropertiesRepository(ref.watch(supabaseClientProvider)),
);

final propertiesProvider =
    AsyncNotifierProvider<PropertiesController, List<Property>>(
      PropertiesController.new,
    );

/// Every manager already active somewhere in the Owner's org — the pool
/// the Add/Edit PG dialog picks from instead of always inviting someone
/// new. Cheap to invalidate/refetch after any assignment change since it's
/// a small list.
final orgManagersProvider = FutureProvider<List<OrgManager>>((ref) async {
  final result = await ref
      .watch(propertiesRepositoryProvider)
      .fetchOrgManagers();
  return result.when(ok: (v) => v, err: (failure) => throw failure);
});

/// Per-property occupancy/rent/complaints, derived live from Rooms,
/// Payments and Complaints — the same ledgers Manager Rooms, Manager
/// Payments and Manager Complaints themselves read — instead of a
/// second, independently-maintained copy on [Property]. Keyed by
/// property id; a property with no entry (still loading, or an id that
/// doesn't exist) should be treated as [PropertyMetrics.zero] by callers.
final propertyMetricsProvider =
    FutureProvider<Map<String, PropertyMetrics>>((ref) async {
      final properties = await ref.watch(propertiesProvider.future);

      // Kick off every property's rooms fetch plus the two portfolio-wide
      // reads before awaiting any of them, so they run concurrently.
      final roomsFutures = {
        for (final property in properties)
          property.id: ref.watch(roomsProvider(property.id).future),
      };
      final paymentsFuture = ref.watch(latestPaymentsProvider(null).future);
      final complaintsFuture = ref.watch(portfolioComplaintsProvider.future);

      final payments = await paymentsFuture;
      final complaints = await complaintsFuture;

      final result = <String, PropertyMetrics>{};
      for (final property in properties) {
        final floors = await roomsFutures[property.id]!;
        var totalBeds = 0;
        var occupiedBeds = 0;
        for (final floor in floors) {
          for (final room in floor.rooms) {
            totalBeds += room.beds.length;
            occupiedBeds += room.beds.where((bed) => !bed.isVacant).length;
          }
        }

        final propertyPayments = payments.where(
          (p) => p.propertyId == property.id,
        );
        // A `partial` period's `amount` is the confirmed-paid portion —
        // real money received — so it counts toward collected too, not
        // just fully-`paid` periods. See backend migration 33.
        final rentCollected = propertyPayments
            .where(
              (p) =>
                  p.status == PaymentStatus.paid ||
                  p.status == PaymentStatus.partial,
            )
            .fold<int>(0, (sum, p) => sum + p.amount);
        final rentExpected = propertyPayments.fold<int>(
          0,
          (sum, p) => sum + p.expectedAmount,
        );
        final openComplaints = complaints
            .where(
              (c) =>
                  c.propertyId == property.id &&
                  c.effectiveStatus != ComplaintStatus.resolved,
            )
            .length;

        result[property.id] = PropertyMetrics(
          totalBeds: totalBeds,
          occupiedBeds: occupiedBeds,
          rentCollected: rentCollected,
          rentExpected: rentExpected,
          openComplaints: openComplaints,
        );
      }
      return result;
    });

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
  }) async {
    final result = await ref
        .read(propertiesRepositoryProvider)
        .addProperty(name: name, address: address, totalBeds: totalBeds);
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
  }) async {
    final result = await ref
        .read(propertiesRepositoryProvider)
        .updateProperty(id, name: name, address: address, totalBeds: totalBeds);
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

  /// Assigns an already-active org manager to [propertyId], or creates a
  /// brand-new manager account and assigns them — exactly one of
  /// [existingManagerId] or both [newManagerName]/[newManagerPhone] should
  /// be given. Refetches the whole list afterwards so [Property.managerName]
  /// reflects the change (the repository call itself returns no updated
  /// row to patch in-place, unlike add/updateProperty).
  Future<AppFailure?> assignManager(
    String propertyId, {
    String? existingManagerId,
    String? newManagerName,
    String? newManagerPhone,
  }) async {
    final repository = ref.read(propertiesRepositoryProvider);
    final result = existingManagerId != null
        ? await repository.assignExistingManager(propertyId, existingManagerId)
        : await repository.inviteAndAssignManager(
            propertyId,
            name: newManagerName!,
            phone: newManagerPhone!,
          );
    final failure = result.when(ok: (_) => null, err: (failure) => failure);
    if (failure == null) {
      await _refetch();
      ref.invalidate(orgManagersProvider);
    }
    return failure;
  }

  Future<AppFailure?> unassignManager(
    String propertyId,
    String managerId,
  ) async {
    final result = await ref
        .read(propertiesRepositoryProvider)
        .unassignManager(propertyId, managerId);
    final failure = result.when(ok: (_) => null, err: (failure) => failure);
    if (failure == null) {
      await _refetch();
    }
    return failure;
  }

  Future<void> _refetch() async {
    final result = await ref.read(propertiesRepositoryProvider).fetchProperties();
    result.when(ok: (properties) => state = AsyncValue.data(properties), err: (_) {});
  }
}
