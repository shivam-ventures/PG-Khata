import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/result.dart';
import 'package:pg_khata/core/theme/app_theme.dart';
import 'package:pg_khata/features/dashboard/application/dashboard_providers.dart';
import 'package:pg_khata/features/dashboard/data/dashboard_repository.dart';
import 'package:pg_khata/features/dashboard/domain/manager_today_data.dart';
import 'package:pg_khata/features/dashboard/domain/owner_dashboard_data.dart';
import 'package:pg_khata/features/dashboard/domain/tenant_home_data.dart';
import 'package:pg_khata/features/dashboard/presentation/manager/manager_today_screen.dart';

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository(this.data);

  final ManagerTodayData data;

  @override
  Future<Result<OwnerDashboardData>> fetchOwnerDashboard() =>
      throw UnimplementedError();

  @override
  Future<Result<ManagerTodayData>> fetchManagerToday({required String pgId}) =>
      Future.value(Ok(data));

  @override
  Future<Result<TenantHomeData>> fetchTenantHome() =>
      throw UnimplementedError();
}

const _withTasks = ManagerTodayData(
  managerFirstName: 'Ramesh',
  pgOptions: [PgOption(id: 'hsr', name: 'HSR PG')],
  currentPgId: 'hsr',
  occupancyLabel: '18/20',
  pendingLabel: '₹25,000',
  complaintsCountLabel: '2 open',
  rentTasks: [
    RentTask(tenantName: 'Rahul Sharma', room: 'B-204', amountLabel: '₹8,500'),
  ],
  complaintTasks: [],
);

const _noTasks = ManagerTodayData(
  managerFirstName: 'Ramesh',
  pgOptions: [PgOption(id: 'ind', name: 'Indiranagar PG')],
  currentPgId: 'ind',
  occupancyLabel: '1/1',
  pendingLabel: '₹0',
  complaintsCountLabel: '0 open',
  rentTasks: [],
  complaintTasks: [],
);

void main() {
  Widget wrap(ManagerTodayData data) {
    return ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          _FakeDashboardRepository(data),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ManagerTodayScreen()),
      ),
    );
  }

  testWidgets('shows rent tasks when there is work to do', (tester) async {
    await tester.pumpWidget(wrap(_withTasks));
    await tester.pumpAndSettle();

    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('₹8,500'), findsOneWidget);
  });

  testWidgets('shows the caught-up state when there is nothing to do', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_noTasks));
    await tester.pumpAndSettle();

    expect(find.text('All caught up for today.'), findsOneWidget);
  });
}
