import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/app_failure.dart';
import 'package:pg_khata/core/errors/result.dart';
import 'package:pg_khata/core/theme/app_theme.dart';
import 'package:pg_khata/features/dashboard/application/dashboard_providers.dart';
import 'package:pg_khata/features/dashboard/data/dashboard_repository.dart';
import 'package:pg_khata/features/dashboard/domain/manager_today_data.dart';
import 'package:pg_khata/features/dashboard/domain/owner_dashboard_data.dart';
import 'package:pg_khata/features/dashboard/domain/tenant_home_data.dart';
import 'package:pg_khata/features/dashboard/presentation/owner/owner_dashboard_screen.dart';
import 'package:pg_khata/shared/widgets/semantic_tone.dart';
import 'package:pg_khata/shared/widgets/skeleton.dart';

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository({this.ownerResult, this.ownerCompleter});

  final Result<OwnerDashboardData>? ownerResult;
  final Completer<Result<OwnerDashboardData>>? ownerCompleter;

  @override
  Future<Result<OwnerDashboardData>> fetchOwnerDashboard() {
    if (ownerCompleter != null) return ownerCompleter!.future;
    return Future.value(ownerResult);
  }

  @override
  Future<Result<ManagerTodayData>> fetchManagerToday({required String pgId}) =>
      throw UnimplementedError();

  @override
  Future<Result<TenantHomeData>> fetchTenantHome() =>
      throw UnimplementedError();
}

const _populated = OwnerDashboardData(
  ownerFirstName: 'Anita',
  attentionItems: [],
  stats: [],
  properties: [
    PropertyOverview(
      name: 'HSR PG',
      occupancyLabel: '18/20',
      rentLabel: '₹1.6L / ₹1.8L',
      complaintsLabel: '2 open',
      complaintsTone: SemanticTone.warning,
      managerName: 'Ramesh K.',
    ),
  ],
);

const _empty = OwnerDashboardData(
  ownerFirstName: 'Anita',
  attentionItems: [],
  stats: [],
  properties: [],
);

void main() {
  Widget wrap({required DashboardRepository repository}) {
    return ProviderScope(
      // Riverpod 3 auto-retries a failing FutureProvider and reports it as
      // still "loading" while retries are pending — disable that here so an
      // injected failure settles into AsyncError immediately, as a test needs.
      retry: (_, _) => null,
      overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: OwnerDashboardScreen()),
      ),
    );
  }

  testWidgets('shows a skeleton while loading', (tester) async {
    final completer = Completer<Result<OwnerDashboardData>>();
    await tester.pumpWidget(
      wrap(repository: _FakeDashboardRepository(ownerCompleter: completer)),
    );

    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);

    completer.complete(const Ok(_empty));
    await tester.pumpAndSettle();
  });

  testWidgets('shows properties and greeting once loaded', (tester) async {
    await tester.pumpWidget(
      wrap(
        repository: _FakeDashboardRepository(ownerResult: const Ok(_populated)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Anita'), findsOneWidget);
    expect(find.text('HSR PG'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no properties', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(repository: _FakeDashboardRepository(ownerResult: const Ok(_empty))),
    );

    await tester.pumpAndSettle();

    expect(find.text('No properties yet'), findsOneWidget);
    expect(find.text('Add Property'), findsOneWidget);
  });

  testWidgets('shows a friendly error message and lets the user retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        repository: _FakeDashboardRepository(
          ownerResult: const Err(UnexpectedFailure()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(const UnexpectedFailure().message), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
