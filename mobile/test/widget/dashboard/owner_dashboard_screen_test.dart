import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/app_failure.dart';
import 'package:pg_khata/core/theme/app_theme.dart';
import 'package:pg_khata/features/auth/application/auth_controller.dart';
import 'package:pg_khata/features/auth/domain/app_user.dart';
import 'package:pg_khata/features/auth/domain/user_role.dart';
import 'package:pg_khata/features/complaints/application/complaints_providers.dart';
import 'package:pg_khata/features/dashboard/presentation/owner/owner_dashboard_screen.dart';
import 'package:pg_khata/features/payments/application/payments_providers.dart';
import 'package:pg_khata/features/properties/application/properties_providers.dart';
import 'package:pg_khata/features/properties/domain/property.dart';
import 'package:pg_khata/features/rooms/application/rooms_providers.dart';
import 'package:pg_khata/shared/widgets/skeleton.dart';

class _FixedAuthController extends AuthController {
  _FixedAuthController(this._user);
  final AppUser? _user;
  @override
  Future<AppUser?> build() async => _user;
}

class _FakePropertiesController extends PropertiesController {
  _FakePropertiesController({this.completer, this.result, this.error});
  final Completer<List<Property>>? completer;
  final List<Property>? result;
  final Object? error;

  @override
  Future<List<Property>> build() {
    if (completer != null) return completer!.future;
    if (error != null) throw error!;
    return Future.value(result);
  }
}

const _owner = AppUser(
  id: 'demo-owner',
  name: 'Anita Sharma',
  phone: '9876543210',
  role: UserRole.owner,
);

const _populated = [
  Property(
    id: 'hsr',
    name: 'HSR PG',
    address: '27th Main, HSR Layout, Bengaluru',
    totalBeds: 20,
    managerName: 'Ramesh K.',
  ),
];

void main() {
  // The Owner Dashboard's ListView now always renders a full stat grid plus
  // any attention items before the properties section, which real content
  // pushes below the default test viewport's cache extent — a Sliver only
  // mounts children within that extent, so a short viewport would leave the
  // properties section un-mounted and invisible to `find.text` even though
  // it's genuinely in the data. A tall viewport keeps everything mounted.
  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap({required PropertiesController Function() properties}) {
    return ProviderScope(
      // Riverpod 3 auto-retries a failing FutureProvider and reports it as
      // still "loading" while retries are pending — disable that here so an
      // injected failure settles into AsyncError immediately, as a test needs.
      retry: (_, _) => null,
      overrides: [
        authControllerProvider.overrideWith(() => _FixedAuthController(_owner)),
        propertiesProvider.overrideWith(properties),
        latestPaymentsProvider.overrideWith((ref, propertyId) async => []),
        portfolioComplaintsProvider.overrideWith((ref) async => []),
        roomsProvider.overrideWith((ref, propertyId) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: OwnerDashboardScreen()),
      ),
    );
  }

  testWidgets('shows a skeleton while loading', (tester) async {
    final completer = Completer<List<Property>>();
    await tester.pumpWidget(
      wrap(properties: () => _FakePropertiesController(completer: completer)),
    );

    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);

    completer.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('shows properties and greeting once loaded', (tester) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      wrap(properties: () => _FakePropertiesController(result: _populated)),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Anita'), findsWidgets);
    expect(find.text('HSR PG'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no properties', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(properties: () => _FakePropertiesController(result: const [])),
    );

    await tester.pumpAndSettle();

    expect(find.text('No PGs yet'), findsOneWidget);
    expect(find.text('Add PG'), findsOneWidget);
  });

  testWidgets('shows a friendly error message and lets the user retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        properties: () =>
            _FakePropertiesController(error: const UnexpectedFailure()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(const UnexpectedFailure().message), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
