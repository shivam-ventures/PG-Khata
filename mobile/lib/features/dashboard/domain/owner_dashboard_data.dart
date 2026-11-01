import '../../../shared/widgets/semantic_tone.dart';
import 'dashboard_stat.dart';

/// A line in the "Needs your attention" card, e.g. "₹32,000 rent pending
/// across 4 tenants". Each variant carries the raw numbers behind that
/// message; the widget formats the actual sentence via `AppLocalizations`.
/// [destination] is a nav-destination key (see `core/routing/app_router.dart`)
/// for screens not yet built in Phase 0 — tapping still navigates, to that
/// feature's placeholder.
sealed class AttentionItem {
  const AttentionItem({required this.destination});

  final String destination;
}

class PendingRentAttention extends AttentionItem {
  const PendingRentAttention({
    required this.amount,
    required this.tenantCount,
  }) : super(destination: 'payments');

  final int amount;
  final int tenantCount;
}

class VacantBedsAttention extends AttentionItem {
  const VacantBedsAttention({
    required this.bedCount,
    required this.propertyNames,
  }) : super(destination: 'rooms');

  final int bedCount;
  final List<String> propertyNames;
}

class StaleComplaintsAttention extends AttentionItem {
  const StaleComplaintsAttention({required this.count})
    : super(destination: 'complaints');

  final int count;
}

/// One property row on the Owner Dashboard's property list.
class PropertyOverview {
  const PropertyOverview({
    required this.name,
    required this.occupiedBeds,
    required this.totalBeds,
    required this.rentCollected,
    required this.rentExpected,
    required this.openComplaints,
    required this.managerName,
  });

  final String name;
  final int occupiedBeds;
  final int totalBeds;
  final int rentCollected;
  final int rentExpected;
  final int openComplaints;
  final String managerName;

  SemanticTone get complaintsTone =>
      openComplaints > 0 ? SemanticTone.warning : SemanticTone.success;
}

/// Everything the Owner Dashboard screen needs to render, sourced from
/// `Owner Dashboard.dc.html`'s mock data.
class OwnerDashboardData {
  const OwnerDashboardData({
    required this.ownerFirstName,
    required this.attentionItems,
    required this.stats,
    required this.properties,
  });

  final String ownerFirstName;
  final List<AttentionItem> attentionItems;
  final List<DashboardStat> stats;
  final List<PropertyOverview> properties;

  bool get hasProperties => properties.isNotEmpty;
  bool get hasAttentionItems => attentionItems.isNotEmpty;
}
