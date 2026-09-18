import '../../../shared/widgets/semantic_tone.dart';
import 'dashboard_stat.dart';

/// A line in the "Needs your attention" card, e.g. "₹32,000 rent pending
/// across 4 tenants". [destination] is a nav-destination key (see
/// `core/routing/app_router.dart`) for screens not yet built in Phase 0 —
/// tapping still navigates, to that feature's placeholder.
class AttentionItem {
  const AttentionItem({required this.text, required this.destination});

  final String text;
  final String destination;
}

/// One property row on the Owner Dashboard's property list.
class PropertyOverview {
  const PropertyOverview({
    required this.name,
    required this.occupancyLabel,
    required this.rentLabel,
    required this.complaintsLabel,
    required this.complaintsTone,
    required this.managerName,
  });

  final String name;
  final String occupancyLabel;
  final String rentLabel;
  final String complaintsLabel;
  final SemanticTone complaintsTone;
  final String managerName;
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
