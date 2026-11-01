/// One tile in a stat grid/row — the `stats` shape shared by the Owner
/// Dashboard's stat grid and the Manager Today mini-stat row. Each variant
/// carries only the raw numbers it needs; the widget formats icon, label,
/// value and sub-text at render time via `AppLocalizations` so the same
/// data renders correctly in any language.
sealed class DashboardStat {
  const DashboardStat();
}

class OccupancyStat extends DashboardStat {
  const OccupancyStat({required this.occupiedBeds, required this.totalBeds});

  final int occupiedBeds;
  final int totalBeds;

  int get percent =>
      totalBeds == 0 ? 0 : (occupiedBeds / totalBeds * 100).round();
}

class RentCollectedStat extends DashboardStat {
  const RentCollectedStat({required this.collected, required this.expected});

  final int collected;
  final int expected;
}

class PendingRentStat extends DashboardStat {
  const PendingRentStat({required this.amount, required this.tenantCount});

  final int amount;
  final int tenantCount;
}

class OpenComplaintsStat extends DashboardStat {
  const OpenComplaintsStat({required this.count, required this.staleCount});

  final int count;
  final int staleCount;
}
