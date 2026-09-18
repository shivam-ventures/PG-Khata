import 'package:flutter/material.dart';

import '../../../core/errors/result.dart';
import '../../../shared/widgets/semantic_tone.dart';
import '../domain/dashboard_stat.dart';
import '../domain/manager_today_data.dart';
import '../domain/owner_dashboard_data.dart';
import '../domain/tenant_home_data.dart';
import 'dashboard_repository.dart';

/// Phase-0 mock backing for [DashboardRepository]. Values are ported
/// verbatim from the approved design's own mock data (`Owner Dashboard.dc.html`,
/// `Manager Today.dc.html`, `Tenant Home.dc.html`) rather than invented, so
/// Phase 0 renders exactly what was approved.
class MockDashboardRepository implements DashboardRepository {
  @override
  Future<Result<OwnerDashboardData>> fetchOwnerDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const Ok(
      OwnerDashboardData(
        ownerFirstName: 'Anita',
        attentionItems: [
          AttentionItem(
            text: '₹32,000 rent pending across 4 tenants',
            destination: 'payments',
          ),
          AttentionItem(
            text: '4 vacant beds — HSR PG, Koramangala PG',
            destination: 'rooms',
          ),
          AttentionItem(
            text: '2 complaints open for more than 48 hours',
            destination: 'complaints',
          ),
        ],
        stats: [
          DashboardStat(
            icon: Icons.home_outlined,
            label: 'Occupancy',
            value: '86%',
            sub: '42 / 49 beds',
            tone: SemanticTone.accent,
          ),
          DashboardStat(
            icon: Icons.currency_rupee,
            label: 'Rent collected',
            value: '₹4.1L',
            sub: 'of ₹4.6L expected',
            tone: SemanticTone.success,
          ),
          DashboardStat(
            icon: Icons.hourglass_bottom,
            label: 'Pending rent',
            value: '₹32,000',
            sub: '4 tenants',
            tone: SemanticTone.warning,
          ),
          DashboardStat(
            icon: Icons.warning_amber_rounded,
            label: 'Open complaints',
            value: '6',
            sub: '2 overdue',
            tone: SemanticTone.danger,
          ),
        ],
        properties: [
          PropertyOverview(
            name: 'HSR PG',
            occupancyLabel: '18/20',
            rentLabel: '₹1.6L / ₹1.8L',
            complaintsLabel: '2 open',
            complaintsTone: SemanticTone.warning,
            managerName: 'Ramesh K.',
          ),
          PropertyOverview(
            name: 'Koramangala PG',
            occupancyLabel: '14/18',
            rentLabel: '₹1.2L / ₹1.3L',
            complaintsLabel: '0 open',
            complaintsTone: SemanticTone.success,
            managerName: 'Divya S.',
          ),
          PropertyOverview(
            name: 'Indiranagar PG',
            occupancyLabel: '10/11',
            rentLabel: '₹1.3L / ₹1.5L',
            complaintsLabel: '4 open',
            complaintsTone: SemanticTone.danger,
            managerName: 'Ramesh K.',
          ),
        ],
      ),
    );
  }

  static const _pgOptions = [
    PgOption(id: 'hsr', name: 'HSR PG'),
    PgOption(id: 'ind', name: 'Indiranagar PG'),
  ];

  @override
  Future<Result<ManagerTodayData>> fetchManagerToday({
    required String pgId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final data = switch (pgId) {
      'ind' => const ManagerTodayData(
        managerFirstName: 'Ramesh',
        pgOptions: _pgOptions,
        currentPgId: 'ind',
        occupancyLabel: '1/1',
        pendingLabel: '₹0',
        complaintsCountLabel: '0 open',
        rentTasks: [],
        complaintTasks: [],
      ),
      _ => const ManagerTodayData(
        managerFirstName: 'Ramesh',
        pgOptions: _pgOptions,
        currentPgId: 'hsr',
        occupancyLabel: '18/20',
        pendingLabel: '₹25,000',
        complaintsCountLabel: '2 open',
        rentTasks: [
          RentTask(
            tenantName: 'Rahul Sharma',
            room: 'B-204',
            amountLabel: '₹8,500',
          ),
          RentTask(
            tenantName: 'Ayesha Khan',
            room: 'A-108',
            amountLabel: '₹9,000',
          ),
          RentTask(
            tenantName: 'Vikram Rao',
            room: 'C-301',
            amountLabel: '₹7,500',
          ),
        ],
        complaintTasks: [
          ComplaintTask(
            title: 'Geyser not working',
            room: 'B-204',
            age: '2 days open',
            status: 'In Progress',
            tone: SemanticTone.warning,
          ),
          ComplaintTask(
            title: 'Wifi down on 2nd floor',
            room: 'Floor 2',
            age: '5 hours open',
            status: 'Reported',
            tone: SemanticTone.danger,
          ),
        ],
      ),
    };
    return Ok(data);
  }

  @override
  Future<Result<TenantHomeData>> fetchTenantHome() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const Ok(
      TenantHomeData(
        firstName: 'Rahul',
        pgName: 'HSR PG',
        pgAddress: '27th Main, HSR Layout, Bengaluru',
        room: 'B-204',
        managerName: 'Ramesh Kumar',
        managerPhone: '+919876500000',
        rentAmountLabel: '₹8,500',
        dueLabel: 'Rent due in 12 days',
        nextDueDateLabel: '28 Sept',
        isRentDueSoon: false,
        isOverdue: false,
        hasPendingCashConfirmation: true,
        pendingCashAmountLabel: '₹8,500',
        announcement: 'Water supply will be interrupted on 18 Sept, 10am–1pm for maintenance.',
        recentPayments: [
          PaymentSummary(
            periodLabel: 'August 2026',
            method: 'UPI',
            date: '3 Aug',
            status: 'Paid',
            tone: SemanticTone.success,
          ),
        ],
        openComplaintTitle: 'Geyser not working',
        openComplaintAge: 'Reported 2 days ago',
        openComplaintStatus: 'In Progress',
      ),
    );
  }
}
