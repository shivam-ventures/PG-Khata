import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../complaints/application/complaints_providers.dart';
import '../../complaints/domain/complaint_status.dart';
import '../../payments/application/payments_providers.dart';
import '../../payments/domain/payment_status.dart';
import '../../rooms/application/rooms_providers.dart';
import '../data/mock_properties_repository.dart';
import '../data/properties_repository.dart';
import '../domain/property.dart';
import '../domain/property_metrics.dart';

/// The single override point for swapping the properties data source: point
/// this at a Supabase-backed implementation in Phase 6.
final propertiesRepositoryProvider = Provider<PropertiesRepository>(
  (ref) => MockPropertiesRepository(),
);

final propertiesProvider =
    AsyncNotifierProvider<PropertiesController, List<Property>>(
      PropertiesController.new,
    );

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
        final rentCollected = propertyPayments
            .where((p) => p.status == PaymentStatus.paid)
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
