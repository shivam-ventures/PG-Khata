import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/theme/app_theme.dart';
import 'package:pg_khata/features/complaints/application/complaints_providers.dart';
import 'package:pg_khata/features/dashboard/presentation/tenant/tenant_home_screen.dart';
import 'package:pg_khata/features/payments/application/payments_providers.dart';
import 'package:pg_khata/features/payments/domain/payment_status.dart';
import 'package:pg_khata/features/payments/domain/rent_payment.dart';
import 'package:pg_khata/features/properties/application/properties_providers.dart';
import 'package:pg_khata/features/properties/domain/property.dart';
import 'package:pg_khata/features/tenants/application/tenants_providers.dart';
import 'package:pg_khata/features/tenants/domain/tenant_record.dart';
import 'package:pg_khata/features/tenants/domain/tenant_status.dart';

final _tenant = TenantRecord(
  id: 't7',
  name: 'Rahul Sharma',
  phone: '9822233445',
  propertyId: 'hsr',
  propertyName: 'HSR PG',
  roomBed: 'B-204',
  rent: 8500,
  joinedDate: DateTime(2026, 1, 1),
  status: TenantStatus.active,
);

const _property = Property(
  id: 'hsr',
  name: 'HSR PG',
  address: '27th Main, HSR Layout, Bengaluru',
  totalBeds: 20,
  managerName: 'Ramesh K.',
);

RentPayment _payment({required PaymentStatus status, required DateTime dueDate}) =>
    RentPayment(
      id: 't7_202609',
      tenantId: 't7',
      tenantName: 'Rahul Sharma',
      propertyId: 'hsr',
      propertyName: 'HSR PG',
      room: 'B-204',
      amount: 8500,
      periodMonth: DateTime(2026, 9),
      dueDate: dueDate,
      status: status,
      paidDate: status == PaymentStatus.paid ? DateTime(2026, 9, 3) : null,
    );

void main() {
  Widget wrap(List<RentPayment> history) {
    return ProviderScope(
      overrides: [
        currentTenantRecordProvider.overrideWith((ref) async => _tenant),
        propertiesProvider.overrideWith(() => _FakePropertiesController()),
        paymentHistoryProvider.overrideWith((ref, tenantId) async => history),
        tenantComplaintsProvider.overrideWith((ref, tenantId) async => []),
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
    await tester.pumpWidget(
      wrap([
        _payment(status: PaymentStatus.paid, dueDate: DateTime(2026, 9, 28)),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're all paid up"), findsOneWidget);
  });

  testWidgets('shows the Pay Rent card when rent is due soon', (tester) async {
    await tester.pumpWidget(
      wrap([
        _payment(status: PaymentStatus.pending, dueDate: DateTime(2026, 9, 28)),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pay Rent'), findsOneWidget);
    expect(find.text('₹8,500'), findsOneWidget);
  });
}

class _FakePropertiesController extends PropertiesController {
  @override
  Future<List<Property>> build() async => const [_property];
}
