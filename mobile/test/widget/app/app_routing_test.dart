import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/app/app.dart';
import 'package:pg_khata/features/auth/application/auth_controller.dart';
import 'package:pg_khata/features/auth/domain/app_user.dart';
import 'package:pg_khata/features/auth/domain/user_role.dart';

/// A fixed-state stand-in for [AuthController] so a test can start already
/// signed in (or signed out) without driving the phone/OTP flow.
class _FixedAuthController extends AuthController {
  _FixedAuthController(this._initialUser);

  final AppUser? _initialUser;

  @override
  Future<AppUser?> build() async => _initialUser;
}

const _owner = AppUser(
  id: 'demo-owner',
  name: 'Anita Sharma',
  phone: '9876543210',
  role: UserRole.owner,
);
const _manager = AppUser(
  id: 'demo-manager',
  name: 'Ramesh Kumar',
  phone: '9876500000',
  role: UserRole.manager,
);
const _tenant = AppUser(
  id: 'demo-tenant',
  name: 'Rahul Sharma',
  phone: '9000000001',
  role: UserRole.tenant,
);

/// `pumpAndSettle` alone stops as soon as no new frame is scheduled — it
/// doesn't fast-forward a plain `Future.delayed` (the dashboard mock
/// repositories' simulated network latency) the way it does an ongoing
/// animation. Advance virtual time past that delay explicitly first.
Future<void> _pumpPastMockLatency(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unauthenticated session lands on phone entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _FixedAuthController(null)),
        ],
        child: const PgKhataApp(),
      ),
    );
    await _pumpPastMockLatency(tester);

    expect(find.text('PG Khata'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
  });

  testWidgets('an Owner session lands on the Owner Dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FixedAuthController(_owner),
          ),
        ],
        child: const PgKhataApp(),
      ),
    );
    await _pumpPastMockLatency(tester);

    expect(find.textContaining('Anita'), findsWidgets);
    expect(find.text('Overview'), findsOneWidget);
  });

  testWidgets('a Manager session lands on Manager Today', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FixedAuthController(_manager),
          ),
        ],
        child: const PgKhataApp(),
      ),
    );
    await _pumpPastMockLatency(tester);

    expect(find.textContaining('Ramesh'), findsWidgets);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('a Tenant session lands on Tenant Home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FixedAuthController(_tenant),
          ),
        ],
        child: const PgKhataApp(),
      ),
    );
    await _pumpPastMockLatency(tester);

    expect(find.textContaining('Rahul'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
  });
}
