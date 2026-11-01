import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../announcements/application/announcements_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../complaints/application/complaints_providers.dart';
import '../../complaints/domain/complaint_status.dart';
import '../../payments/application/payments_providers.dart';
import '../../payments/domain/payment_status.dart';
import '../../payments/domain/rent_payment.dart';
import '../../properties/application/properties_providers.dart';
import '../../properties/domain/property.dart';
import '../../properties/domain/property_metrics.dart';
import '../../rooms/application/rooms_providers.dart';
import '../../tenants/application/tenants_providers.dart';
import '../domain/dashboard_stat.dart';
import '../domain/manager_today_data.dart';
import '../domain/owner_dashboard_data.dart';
import '../domain/tenant_home_data.dart';

/// The PG a Manager is currently viewing — mirrors the design's `?pg=`
/// query param, as real, testable state instead of a URL hack (see
/// `docs/architecture.md`'s routing section). Shared by every Manager
/// screen ([PgContextBar] shows and switches it everywhere, not just here).
final managerSelectedPgIdProvider =
    NotifierProvider<ManagerSelectedPgIdNotifier, String>(
      ManagerSelectedPgIdNotifier.new,
    );

class ManagerSelectedPgIdNotifier extends Notifier<String> {
  @override
  String build() {
    // Was hardcoded to the Phase-1 mock's 'hsr' — real property ids are
    // UUIDs, so that default never matched anything once Properties/Rooms
    // were wired to Supabase (every Manager screen silently showed empty).
    // `propertiesProvider` is already RLS-scoped to exactly this Manager's
    // assigned properties (the same query an Owner's portfolio view makes;
    // RLS decides which rows come back), so snap to the first one once it
    // loads, unless the current selection is still a real, valid choice
    // (e.g. survives a re-login without resetting a Manager's last pick).
    ref.listen(propertiesProvider, (previous, next) {
      final properties = next.value;
      if (properties == null || properties.isEmpty) return;
      final currentIsValid = properties.any((p) => p.id == state);
      if (!currentIsValid) {
        state = properties.first.id;
      }
    });
    // ref.listen only fires on a FUTURE transition of propertiesProvider —
    // if it's already resolved by the time this notifier first builds
    // (e.g. some other screen already triggered the fetch), that initial
    // value would otherwise never be picked up.
    final alreadyLoaded = ref.read(propertiesProvider).value;
    if (alreadyLoaded != null && alreadyLoaded.isNotEmpty) {
      return alreadyLoaded.first.id;
    }
    return '';
  }

  void select(String pgId) => state = pgId;
}

String _firstName(String fullName) => fullName.split(' ').first;

/// The Owner Dashboard's numbers are composed straight from the same
/// properties/payments/complaints repositories the Properties, Payments and
/// Complaints screens themselves read — not a separate, independently
/// maintained mock, which is how the dashboard used to silently drift out
/// of sync with what those screens actually showed.
final ownerDashboardProvider = FutureProvider<OwnerDashboardData>((ref) async {
  // Kick off every independent fetch before awaiting any of them, so they
  // run concurrently instead of stacking each mock's own latency in series.
  final userFuture = ref.watch(authControllerProvider.future);
  final propertiesFuture = ref.watch(propertiesProvider.future);
  final paymentsFuture = ref.watch(latestPaymentsProvider(null).future);
  final complaintsFuture = ref.watch(portfolioComplaintsProvider.future);
  final metricsFuture = ref.watch(propertyMetricsProvider.future);

  final user = await userFuture;
  final properties = await propertiesFuture;
  final payments = await paymentsFuture;
  final complaints = await complaintsFuture;
  final metrics = await metricsFuture;

  PropertyMetrics metricsFor(String propertyId) =>
      metrics[propertyId] ?? PropertyMetrics.zero;

  final pendingPayments = payments.where((p) => p.status.isCollectable).toList();
  // outstandingAmount, not amount — a `partial` period's `amount` is what
  // was already paid, not what's still owed. See RentPayment.outstandingAmount.
  final pendingTotal = pendingPayments.fold<int>(
    0,
    (sum, p) => sum + p.outstandingAmount,
  );
  final vacantBeds = properties.fold<int>(
    0,
    (sum, p) {
      final m = metricsFor(p.id);
      return sum + (m.totalBeds - m.occupiedBeds);
    },
  );
  final openComplaints = complaints
      .where((c) => c.effectiveStatus != ComplaintStatus.resolved)
      .toList();
  final staleComplaints = openComplaints
      .where((c) => DateTime.now().difference(c.reportedAt) >= const Duration(hours: 48))
      .length;

  final attentionItems = [
    if (pendingPayments.isNotEmpty)
      PendingRentAttention(
        amount: pendingTotal,
        tenantCount: pendingPayments.length,
      ),
    if (vacantBeds > 0)
      VacantBedsAttention(
        bedCount: vacantBeds,
        propertyNames: [
          for (final p in properties)
            if (metricsFor(p.id).occupiedBeds < metricsFor(p.id).totalBeds)
              p.name,
        ],
      ),
    if (staleComplaints > 0) StaleComplaintsAttention(count: staleComplaints),
  ];

  final totalBeds = properties.fold<int>(0, (sum, p) => sum + metricsFor(p.id).totalBeds);
  final occupiedBeds = properties.fold<int>(
    0,
    (sum, p) => sum + metricsFor(p.id).occupiedBeds,
  );
  final rentCollected = properties.fold<int>(
    0,
    (sum, p) => sum + metricsFor(p.id).rentCollected,
  );
  final rentExpected = properties.fold<int>(
    0,
    (sum, p) => sum + metricsFor(p.id).rentExpected,
  );
  final stats = [
    OccupancyStat(occupiedBeds: occupiedBeds, totalBeds: totalBeds),
    RentCollectedStat(collected: rentCollected, expected: rentExpected),
    PendingRentStat(amount: pendingTotal, tenantCount: pendingPayments.length),
    OpenComplaintsStat(count: openComplaints.length, staleCount: staleComplaints),
  ];

  PropertyOverview overviewFor(Property property) {
    final m = metricsFor(property.id);
    return PropertyOverview(
      name: property.name,
      occupiedBeds: m.occupiedBeds,
      totalBeds: m.totalBeds,
      rentCollected: m.rentCollected,
      rentExpected: m.rentExpected,
      openComplaints: m.openComplaints,
      managerName: property.managerName,
    );
  }

  final propertyOverviews = [for (final property in properties) overviewFor(property)];

  return OwnerDashboardData(
    ownerFirstName: user != null ? _firstName(user.name) : '',
    attentionItems: attentionItems,
    stats: stats,
    properties: propertyOverviews,
  );
});

/// The Manager Today numbers are read from the exact same
/// property-scoped providers Manager Payments, Manager Rooms and Manager
/// Complaints already use, instead of a separately hardcoded copy — so
/// "2 open" here can never disagree with what Complaints itself shows.
final managerTodayProvider = FutureProvider<ManagerTodayData>((ref) async {
  final pgId = ref.watch(managerSelectedPgIdProvider);
  final userFuture = ref.watch(authControllerProvider.future);
  final paymentsFuture = ref.watch(latestPaymentsProvider(pgId).future);
  final complaintsFuture = ref.watch(managerComplaintsProvider(pgId).future);
  final floorsFuture = ref.watch(roomsProvider(pgId).future);

  final user = await userFuture;
  final payments = await paymentsFuture;
  final complaints = await complaintsFuture;
  final floors = await floorsFuture;

  final totalBeds = floors.fold<int>(
    0,
    (sum, floor) => sum + floor.rooms.fold(0, (s, r) => s + r.beds.length),
  );
  final occupiedBeds = floors.fold<int>(
    0,
    (sum, floor) =>
        sum + floor.rooms.fold(0, (s, r) => s + r.beds.where((b) => !b.isVacant).length),
  );

  final collectable = payments.where((p) => p.status.isCollectable).toList();
  final pendingTotal = collectable.fold<int>(
    0,
    (sum, p) => sum + p.outstandingAmount,
  );
  final openComplaints = complaints
      .where((c) => c.effectiveStatus != ComplaintStatus.resolved)
      .toList();

  return ManagerTodayData(
    managerFirstName: user != null ? _firstName(user.name) : '',
    occupiedBeds: occupiedBeds,
    totalBeds: totalBeds,
    pendingAmount: pendingTotal,
    openComplaintsCount: openComplaints.length,
    rentTasks: [
      for (final payment in collectable)
        RentTask(
          tenantName: payment.tenantName,
          room: payment.room,
          amount: payment.outstandingAmount,
        ),
    ],
    complaintTasks: [
      for (final complaint in openComplaints)
        ComplaintTask(
          title: complaint.title,
          room: complaint.room,
          reportedAt: complaint.reportedAt,
          status: complaint.effectiveStatus,
        ),
    ],
  );
});

/// `null` means the signed-in tenant has no assigned bed yet — see
/// [currentTenantRecordProvider]. The screen shows a dedicated empty state
/// for that instead of forcing a placeholder through this shape.
final tenantHomeProvider = FutureProvider<TenantHomeData?>((ref) async {
  final tenantFuture = ref.watch(currentTenantRecordProvider.future);
  // Independent of the tenant lookup above, so it can run alongside it
  // instead of waiting for it to finish first.
  final propertiesFuture = ref.watch(propertiesProvider.future);

  final tenant = await tenantFuture;
  if (tenant == null) return null;

  final historyFuture = ref.watch(paymentHistoryProvider(tenant.id).future);
  final complaintsFuture = ref.watch(tenantComplaintsProvider(tenant.id).future);
  final announcementFuture = ref.watch(
    currentAnnouncementProvider(tenant.propertyId).future,
  );

  final properties = await propertiesFuture;
  Property? property;
  for (final p in properties) {
    if (p.id == tenant.propertyId) {
      property = p;
      break;
    }
  }

  final history = await historyFuture;
  final complaints = await complaintsFuture;
  final announcement = await announcementFuture;

  final RentPayment? current = history.isEmpty ? null : history.first;
  // A `partial` period still has a real balance the tenant owes — nudge
  // them the same way pending/overdue does, not just once it's 100% unpaid.
  final isRentDueSoon =
      current != null &&
      (current.status == PaymentStatus.pending ||
          current.status == PaymentStatus.overdue ||
          current.status == PaymentStatus.partial);
  final isOverdue = current?.status == PaymentStatus.overdue;

  final awaitingConfirmation = history
      .where((p) => p.status == PaymentStatus.awaitingConfirmation)
      .toList();
  final hasPendingCashConfirmation = awaitingConfirmation.isNotEmpty;

  final openComplaint = complaints
      .where((c) => c.effectiveStatus != ComplaintStatus.resolved)
      .toList();

  return TenantHomeData(
    firstName: _firstName(tenant.name),
    pgName: property?.name ?? tenant.propertyName,
    pgAddress: property?.address ?? '',
    room: tenant.roomBed,
    managerName: property?.managerName ?? '',
    // outstandingAmount so a partially-paid current period shows the real
    // remaining balance here, not the full rent again.
    rentAmount: current?.outstandingAmount ?? tenant.rent,
    currentDueDate: current?.dueDate,
    isRentDueSoon: isRentDueSoon,
    isOverdue: isOverdue,
    hasPendingCashConfirmation: hasPendingCashConfirmation,
    pendingCashAmount: hasPendingCashConfirmation
        ? awaitingConfirmation.first.amount
        : null,
    recentPayments: [
      for (final payment in history.where((p) => p.status == PaymentStatus.paid).take(3))
        PaymentSummary(
          periodMonth: payment.periodMonth,
          method: payment.method,
          paidDate: payment.paidDate!,
          status: PaymentStatus.paid,
        ),
    ],
    openComplaintTitle: openComplaint.isEmpty ? null : openComplaint.first.title,
    openComplaintReportedAt: openComplaint.isEmpty
        ? null
        : openComplaint.first.reportedAt,
    openComplaintStatus: openComplaint.isEmpty
        ? null
        : openComplaint.first.effectiveStatus,
    announcement: announcement?.body,
  );
});
