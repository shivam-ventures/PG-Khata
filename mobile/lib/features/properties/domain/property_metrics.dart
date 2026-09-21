import 'package:flutter/foundation.dart';

/// A property's operational numbers for the current period — occupancy,
/// rent, open complaints. Computed live from Rooms/Payments/Complaints (see
/// `propertyMetricsProvider`) rather than stored on [Property] itself,
/// which used to keep its own copy that had no way to stay in sync with
/// those ledgers once a bed was assigned or a payment recorded elsewhere.
@immutable
class PropertyMetrics {
  const PropertyMetrics({
    required this.totalBeds,
    required this.occupiedBeds,
    required this.rentCollected,
    required this.rentExpected,
    required this.openComplaints,
  });

  final int totalBeds;
  final int occupiedBeds;
  final int rentCollected;
  final int rentExpected;
  final int openComplaints;

  double get occupancyFraction => totalBeds == 0 ? 0 : occupiedBeds / totalBeds;

  static const zero = PropertyMetrics(
    totalBeds: 0,
    occupiedBeds: 0,
    rentCollected: 0,
    rentExpected: 0,
    openComplaints: 0,
  );
}
