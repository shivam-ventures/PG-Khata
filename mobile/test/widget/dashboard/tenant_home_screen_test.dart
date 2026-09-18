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
import 'package:pg_khata/features/dashboard/presentation/tenant/tenant_home_screen.dart';

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository(this.data);

  final TenantHomeData data;

  @override
  Future<Result<OwnerDashboardData>> fetchOwnerDashboard() =>
      throw UnimplementedError();

  @override
  Future<Result<ManagerTodayData>> fetchManagerToday({required String pgId}) =>
      throw UnimplementedError();

  @override
  Future<Result<TenantHomeData>> fetchTenantHome() => Future.value(Ok(data));
}

const _paidUp = TenantHomeData(
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
  hasPendingCashConfirmation: false,
  recentPayments: [],
);

const _dueSoon = TenantHomeData(
  firstName: 'Rahul',
  pgName: 'HSR PG',
  pgAddress: '27th Main, HSR Layout, Bengaluru',
  room: 'B-204',
  managerName: 'Ramesh Kumar',
  managerPhone: '+919876500000',
  rentAmountLabel: '₹8,500',
  dueLabel: 'Rent due in 2 days',
  nextDueDateLabel: '18 Sept',
  isRentDueSoon: true,
  isOverdue: false,
  hasPendingCashConfirmation: false,
  recentPayments: [],
);

void main() {
  Widget wrap(TenantHomeData data) {
    return ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          _FakeDashboardRepository(data),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: TenantHomeScreen()),
      ),
    );
  }

  testWidgets('shows the all-paid-up card when rent is not due soon', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_paidUp));
    await tester.pumpAndSettle();

    expect(find.text("You're all paid up"), findsOneWidget);
  });

  testWidgets('shows the Pay Rent card when rent is due soon', (tester) async {
    await tester.pumpWidget(wrap(_dueSoon));
    await tester.pumpAndSettle();

    expect(find.text('Pay Rent'), findsOneWidget);
    expect(find.text('₹8,500'), findsOneWidget);
  });
}
