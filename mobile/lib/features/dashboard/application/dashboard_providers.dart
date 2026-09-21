import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_label_formatter.dart';
import '../../../core/utils/relative_time_formatter.dart';
import '../../../shared/widgets/semantic_tone.dart';
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
  String build() => 'hsr';

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
  final pendingTotal = pendingPayments.fold<int>(0, (sum, p) => sum + p.amount);
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
      AttentionItem(
        text:
            '${CurrencyFormatter.rupees(pendingTotal)} rent pending across '
            '${pendingPayments.length} tenant${pendingPayments.length == 1 ? '' : 's'}',
        destination: 'payments',
      ),
    if (vacantBeds > 0)
      AttentionItem(
        text:
            '$vacantBeds vacant bed${vacantBeds == 1 ? '' : 's'} — '
            '${properties.where((p) {
              final m = metricsFor(p.id);
              return m.occupiedBeds < m.totalBeds;
            }).map((p) => p.name).join(', ')}',
        destination: 'rooms',
      ),
    if (staleComplaints > 0)
      AttentionItem(
        text:
            '$staleComplaints complaint${staleComplaints == 1 ? '' : 's'} open '
            'for more than 48 hours',
        destination: 'complaints',
      ),
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
  final occupancyPct = totalBeds == 0 ? 0 : (occupiedBeds / totalBeds * 100).round();

  final stats = [
    DashboardStat(
      icon: Icons.home_outlined,
      label: 'Occupancy',
      value: '$occupancyPct%',
      sub: '$occupiedBeds / $totalBeds beds',
      tone: SemanticTone.accent,
    ),
    DashboardStat(
      icon: Icons.currency_rupee,
      label: 'Rent collected',
      value: CurrencyFormatter.rupees(rentCollected),
      sub: 'of ${CurrencyFormatter.rupees(rentExpected)} expected',
      tone: SemanticTone.success,
    ),
    DashboardStat(
      icon: Icons.hourglass_bottom,
      label: 'Pending rent',
      value: CurrencyFormatter.rupees(pendingTotal),
      sub: '${pendingPayments.length} tenant${pendingPayments.length == 1 ? '' : 's'}',
      tone: SemanticTone.warning,
    ),
    DashboardStat(
      icon: Icons.warning_amber_rounded,
      label: 'Open complaints',
      value: '${openComplaints.length}',
      sub: '$staleComplaints overdue',
      tone: SemanticTone.danger,
    ),
  ];

  PropertyOverview overviewFor(Property property) {
    final m = metricsFor(property.id);
    return PropertyOverview(
      name: property.name,
      occupancyLabel: '${m.occupiedBeds}/${m.totalBeds}',
      rentLabel:
          '${CurrencyFormatter.rupees(m.rentCollected)} / '
          '${CurrencyFormatter.rupees(m.rentExpected)}',
      complaintsLabel: '${m.openComplaints} open',
      complaintsTone: m.openComplaints > 0
          ? SemanticTone.warning
          : SemanticTone.success,
      managerName: property.managerName,
    );
  }

  final propertyOverviews = [for (final property in properties) overviewFor(property)];

  return OwnerDashboardData(
    ownerFirstName: user != null ? _firstName(user.name) : 'Owner',
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
  final pendingTotal = collectable.fold<int>(0, (sum, p) => sum + p.amount);
  final openComplaints = complaints
      .where((c) => c.effectiveStatus != ComplaintStatus.resolved)
      .toList();

  return ManagerTodayData(
    managerFirstName: user != null ? _firstName(user.name) : 'Manager',
    occupancyLabel: '$occupiedBeds/$totalBeds',
    pendingLabel: CurrencyFormatter.rupees(pendingTotal),
    complaintsCountLabel: '${openComplaints.length} open',
    rentTasks: [
      for (final payment in collectable)
        RentTask(
          tenantName: payment.tenantName,
          room: payment.room,
          amountLabel: CurrencyFormatter.rupees(payment.amount),
        ),
    ],
    complaintTasks: [
      for (final complaint in openComplaints)
        ComplaintTask(
          title: complaint.title,
          room: complaint.room,
          age: RelativeTimeFormatter.open(complaint.reportedAt),
          status: complaint.effectiveStatus.label,
          tone: complaint.effectiveStatus.tone,
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

  final RentPayment? current = history.isEmpty ? null : history.first;
  final isRentDueSoon =
      current != null &&
      (current.status == PaymentStatus.pending ||
          current.status == PaymentStatus.overdue);
  final isOverdue = current?.status == PaymentStatus.overdue;

  final awaitingConfirmation = history
      .where((p) => p.status == PaymentStatus.awaitingConfirmation)
      .toList();
  final hasPendingCashConfirmation = awaitingConfirmation.isNotEmpty;

  String dueLabel = '';
  String nextDueDateLabel = '';
  if (current != null) {
    if (isRentDueSoon) {
      final days = current.dueDate.difference(DateTime.now()).inDays;
      dueLabel = isOverdue
          ? 'Rent overdue'
          : days <= 0
          ? 'Rent due today'
          : 'Rent due in $days day${days == 1 ? '' : 's'}';
    } else {
      final next = DateTime(
        current.dueDate.year,
        current.dueDate.month + 1,
        current.dueDate.day,
      );
      nextDueDateLabel = DateLabelFormatter.short(next);
    }
  }

  final openComplaint = complaints
      .where((c) => c.effectiveStatus != ComplaintStatus.resolved)
      .toList();

  return TenantHomeData(
    firstName: _firstName(tenant.name),
    pgName: property?.name ?? tenant.propertyName,
    pgAddress: property?.address ?? '',
    room: tenant.roomBed,
    managerName: property?.managerName ?? 'Your manager',
    rentAmountLabel: CurrencyFormatter.rupees(current?.expectedAmount ?? tenant.rent),
    dueLabel: dueLabel,
    nextDueDateLabel: nextDueDateLabel,
    isRentDueSoon: isRentDueSoon,
    isOverdue: isOverdue,
    hasPendingCashConfirmation: hasPendingCashConfirmation,
    pendingCashAmountLabel: hasPendingCashConfirmation
        ? CurrencyFormatter.rupees(awaitingConfirmation.first.amount)
        : null,
    recentPayments: [
      for (final payment in history.where((p) => p.status == PaymentStatus.paid).take(3))
        PaymentSummary(
          periodLabel: DateLabelFormatter.monthYear(payment.periodMonth),
          method: payment.method?.label ?? '—',
          date: DateLabelFormatter.short(payment.paidDate!),
          status: PaymentStatus.paid.label,
          tone: PaymentStatus.paid.tone,
        ),
    ],
    openComplaintTitle: openComplaint.isEmpty ? null : openComplaint.first.title,
    openComplaintAge: openComplaint.isEmpty
        ? null
        : 'Reported ${RelativeTimeFormatter.ago(openComplaint.first.reportedAt)}',
    openComplaintStatus: openComplaint.isEmpty
        ? null
        : openComplaint.first.effectiveStatus.label,
  );
});
