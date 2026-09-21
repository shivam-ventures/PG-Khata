import 'package:flutter/foundation.dart';

/// One bar in the "Revenue by property" chart.
@immutable
class RevenueBar {
  const RevenueBar({required this.propertyName, required this.amount});

  final String propertyName;
  final int amount;
}

/// One point in the occupancy trend chart — see [ReportsData]'s doc comment
/// for why this stays illustrative rather than computed.
@immutable
class OccupancyPoint {
  const OccupancyPoint({required this.monthLabel, required this.percent});

  final String monthLabel;
  final int percent;
}

/// One row in the "Property comparison" list.
@immutable
class PropertyComparisonRow {
  const PropertyComparisonRow({
    required this.propertyName,
    required this.occupancyLabel,
    required this.revenue,
    required this.openComplaints,
    required this.managerName,
  });

  final String propertyName;
  final String occupancyLabel;
  final int revenue;
  final int openComplaints;
  final String managerName;
}

/// Everything the Owner's Reports screen needs. Mirrors `Reports.dc.html`,
/// but computed live off [PropertiesRepository], [PaymentsRepository] and
/// [ComplaintsRepository] wherever those repositories actually hold the
/// data — only [occupancyTrend] stays illustrative/static, since none of
/// the Phase 0-5 mocks track a historical snapshot to compute a real trend
/// from; that becomes real once Phase 6 adds actual time-series storage.
@immutable
class ReportsData {
  const ReportsData({
    required this.totalRevenue,
    required this.totalExpected,
    required this.avgOccupancyPercent,
    required this.avgDaysLate,
    required this.complaintResolutionPercent,
    required this.revenueByProperty,
    required this.occupancyTrend,
    required this.propertyComparison,
  });

  final int totalRevenue;
  final int totalExpected;
  final int avgOccupancyPercent;
  final double avgDaysLate;
  final int complaintResolutionPercent;
  final List<RevenueBar> revenueByProperty;
  final List<OccupancyPoint> occupancyTrend;
  final List<PropertyComparisonRow> propertyComparison;
}
