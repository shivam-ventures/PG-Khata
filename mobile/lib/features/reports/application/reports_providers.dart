import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../complaints/application/complaints_providers.dart';
import '../../complaints/domain/complaint_status.dart';
import '../../payments/application/payments_providers.dart';
import '../../payments/domain/payment_status.dart';
import '../../properties/application/properties_providers.dart';
import '../../properties/domain/property_metrics.dart';
import '../domain/report_data.dart';

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The last 6 months' occupancy, ending at the current month — illustrative
/// only (see [ReportsData]'s doc comment), but the month *labels* stay
/// live so the chart never shows a stale year-old month.
List<OccupancyPoint> _occupancyTrend() {
  const illustrativePercents = [78, 80, 83, 85, 84, 86];
  final now = DateTime.now();
  return [
    for (var i = 5; i >= 0; i--)
      OccupancyPoint(
        monthLabel: _monthAbbrev[DateTime(now.year, now.month - i).month - 1],
        percent: illustrativePercents[5 - i],
      ),
  ];
}

final reportsProvider = FutureProvider<ReportsData>((ref) async {
  final properties = await ref.watch(propertiesProvider.future);
  final metrics = await ref.watch(propertyMetricsProvider.future);

  PropertyMetrics metricsFor(String propertyId) =>
      metrics[propertyId] ?? PropertyMetrics.zero;

  final latestPaymentsResult = await ref
      .watch(paymentsRepositoryProvider)
      .fetchLatestPayments();
  final payments = latestPaymentsResult.when(
    ok: (v) => v,
    err: (failure) => throw failure,
  );

  final complaintsResult = await ref
      .watch(complaintsRepositoryProvider)
      .fetchComplaints();
  final complaints = complaintsResult.when(
    ok: (v) => v,
    err: (failure) => throw failure,
  );

  final totalRevenue = properties.fold<int>(
    0,
    (sum, p) => sum + metricsFor(p.id).rentCollected,
  );
  final totalExpected = properties.fold<int>(
    0,
    (sum, p) => sum + metricsFor(p.id).rentExpected,
  );
  final avgOccupancy = properties.isEmpty
      ? 0
      : (properties.fold<double>(
                  0,
                  (sum, p) => sum + metricsFor(p.id).occupancyFraction,
                ) /
                properties.length *
                100)
            .round();

  final paidPayments = payments
      .where((p) => p.status == PaymentStatus.paid && p.paidDate != null)
      .toList();
  final avgDaysLate = paidPayments.isEmpty
      ? 0.0
      : paidPayments.fold<int>(
              0,
              (sum, p) =>
                  sum + p.paidDate!.difference(p.dueDate).inDays.clamp(0, 999),
            ) /
            paidPayments.length;

  final resolvedCount = complaints
      .where((c) => c.effectiveStatus == ComplaintStatus.resolved)
      .length;
  final resolutionPercent = complaints.isEmpty
      ? 0
      : (resolvedCount / complaints.length * 100).round();

  return ReportsData(
    totalRevenue: totalRevenue,
    totalExpected: totalExpected,
    avgOccupancyPercent: avgOccupancy,
    avgDaysLate: avgDaysLate,
    complaintResolutionPercent: resolutionPercent,
    revenueByProperty: [
      for (final property in properties)
        RevenueBar(
          propertyName: property.name,
          amount: metricsFor(property.id).rentCollected,
        ),
    ],
    occupancyTrend: _occupancyTrend(),
    propertyComparison: [
      for (final property in properties)
        PropertyComparisonRow(
          propertyName: property.name,
          occupancyLabel:
              '${metricsFor(property.id).occupiedBeds}/${metricsFor(property.id).totalBeds}',
          revenue: metricsFor(property.id).rentCollected,
          openComplaints: metricsFor(property.id).openComplaints,
          managerName: property.managerName,
        ),
    ],
  );
});
