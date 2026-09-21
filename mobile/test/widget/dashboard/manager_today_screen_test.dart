import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/theme/app_theme.dart';
import 'package:pg_khata/features/auth/application/auth_controller.dart';
import 'package:pg_khata/features/auth/domain/app_user.dart';
import 'package:pg_khata/features/auth/domain/user_role.dart';
import 'package:pg_khata/features/complaints/application/complaints_providers.dart';
import 'package:pg_khata/features/dashboard/presentation/manager/manager_today_screen.dart';
import 'package:pg_khata/features/payments/application/payments_providers.dart';
import 'package:pg_khata/features/payments/domain/payment_method.dart';
import 'package:pg_khata/features/payments/domain/payment_status.dart';
import 'package:pg_khata/features/payments/domain/rent_payment.dart';
import 'package:pg_khata/features/properties/application/properties_providers.dart';
import 'package:pg_khata/features/properties/domain/property.dart';
import 'package:pg_khata/features/rooms/application/rooms_providers.dart';

class _FixedAuthController extends AuthController {
  _FixedAuthController(this._user);
  final AppUser? _user;
  @override
  Future<AppUser?> build() async => _user;
}

const _manager = AppUser(
  id: 'demo-manager',
  name: 'Ramesh Kumar',
  phone: '9876500000',
  role: UserRole.manager,
);

RentPayment _payment(String id, {required PaymentStatus status}) => RentPayment(
  id: id,
  tenantId: id,
  tenantName: 'Rahul Sharma',
  propertyId: 'hsr',
  propertyName: 'HSR PG',
  room: 'B-204',
  amount: 8500,
  periodMonth: DateTime(2026, 9),
  dueDate: DateTime(2026, 9, 28),
  status: status,
  method: status == PaymentStatus.paid ? PaymentMethod.upi : null,
);

void main() {
  Widget wrap({required List<RentPayment> payments}) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _FixedAuthController(_manager)),
        latestPaymentsProvider.overrideWith((ref, propertyId) async => payments),
        managerComplaintsProvider.overrideWith((ref, propertyId) async => []),
        roomsProvider.overrideWith((ref, propertyId) async => []),
        propertiesProvider.overrideWith(() => _FakePropertiesController()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ManagerTodayScreen()),
      ),
    );
  }

  testWidgets('shows rent tasks when there is work to do', (tester) async {
    await tester.pumpWidget(
      wrap(payments: [_payment('t7_202609', status: PaymentStatus.pending)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rahul Sharma'), findsOneWidget);
    // The "Pending today" mini-stat and the rent-task row now both derive
    // from the same real payment, so the amount legitimately appears twice.
    expect(find.text('₹8,500'), findsWidgets);
  });

  testWidgets('shows the caught-up state when there is nothing to do', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(payments: [_payment('t7_202609', status: PaymentStatus.paid)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('All caught up for today.'), findsOneWidget);
  });
}

class _FakePropertiesController extends PropertiesController {
  @override
  Future<List<Property>> build() async => const [];
}
