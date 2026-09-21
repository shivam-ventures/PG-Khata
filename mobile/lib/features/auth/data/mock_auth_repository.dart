import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/app_user.dart';
import '../domain/user_role.dart';
import 'auth_repository.dart';

/// Phase-0 mock backing for [AuthRepository]. There is no real backend yet
/// (see `docs/DECISIONS.md`'s 2026-09-18 entry) — this simulates network
/// latency and resolves a role from a small seeded set of demo accounts,
/// since there's no `profiles` table yet to look one up in.
///
/// This seeded-role mapping is a Phase-0 demo affordance only, not the
/// self-registration/role-self-select flow the product decision in
/// `docs/design-readme-reconciliation.md` §6.3 explicitly defers — it goes
/// away once [AuthRepository] is backed by real Supabase auth in Phase 6.
class MockAuthRepository implements AuthRepository {
  static const _validOtp = '123456';

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
    return Ok(user);
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
