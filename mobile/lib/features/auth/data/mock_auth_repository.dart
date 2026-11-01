import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/app_user.dart';
import '../domain/user_role.dart';
import 'auth_repository.dart';

/// Phase-0 mock backing for [AuthRepository], superseded by
/// [SupabaseAuthRepository] now that a real backend exists — kept only for
/// UI development/tests that want auth without a network round-trip. This
/// simulates network latency and resolves a role from a small seeded set of
/// demo accounts, since there's no `profiles` table to look one up in.
///
/// This seeded-role mapping is a mock-only affordance, not the
/// self-registration/role-self-select flow the product decision in
/// `docs/design-readme-reconciliation.md` §6.3 explicitly defers.
class MockAuthRepository implements AuthRepository {
  static const _validOtp = '123456';

  AppUser? _current;

  static const _demoUsers = <String, AppUser>{
    '9876543210': AppUser(
      id: 'demo-owner',
      name: 'Anita Sharma',
      phone: '9876543210',
      role: UserRole.owner,
    ),
    '9876500000': AppUser(
      id: 'demo-manager',
      name: 'Ramesh Kumar',
      phone: '9876500000',
      role: UserRole.manager,
    ),
    // Matches Rahul Sharma's own phone in the seeded tenant roster
    // (`MockTenantsRepository`, t7 — HSR PG, B-204) so this demo login
    // resolves to a real tenancy via `currentTenantRecordProvider`'s
    // phone match, instead of a demo identity with nothing behind it.
    '9822233445': AppUser(
      id: 'demo-tenant',
      name: 'Rahul Sharma',
      phone: '9822233445',
      role: UserRole.tenant,
    ),
  };

  @override
  Future<Result<void>> sendOtp(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const Ok(null);
  }

  @override
  Future<Result<AppUser>> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (otp != _validOtp) {
      return const Err(InvalidOtpFailure());
    }
    final user =
        _demoUsers[phoneNumber] ??
        AppUser(
          id: 'demo-$phoneNumber',
          name: 'New Tenant',
          phone: phoneNumber,
          role: UserRole.tenant,
        );
    _current = user;
    return Ok(user);
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _current = null;
  }

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<Result<AppUser>> updatePreferences({
    String? preferredLanguage,
    bool? notifyComplaints,
    bool? notifyAnnouncements,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final current = _current;
    if (current == null) return const Err(UnexpectedFailure());
    final updated = AppUser(
      id: current.id,
      name: current.name,
      phone: current.phone,
      role: current.role,
      preferredLanguage: preferredLanguage ?? current.preferredLanguage,
      notifyComplaints: notifyComplaints ?? current.notifyComplaints,
      notifyAnnouncements: notifyAnnouncements ?? current.notifyAnnouncements,
    );
    _current = updated;
    return Ok(updated);
  }
}
