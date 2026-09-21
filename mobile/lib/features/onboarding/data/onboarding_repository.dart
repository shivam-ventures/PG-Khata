import '../../../core/errors/result.dart';
import '../domain/tenant_invite.dart';

/// The invite-link entry point from `Auth.dc.html`'s `hasInvite` branch:
/// resolve a bed-specific token, then verify the invited person's phone —
/// this *is* their first real login, per `docs/DECISIONS.md`'s 2026-09-15
/// onboarding entry. [MockOnboardingRepository] backs this in Phase 2; a
/// Supabase-backed implementation replaces it in Phase 6 behind the same
/// interface.
abstract interface class OnboardingRepository {
  Future<Result<TenantInvite>> resolveInvite(String token);

  Future<Result<void>> sendOtp(String phoneNumber);

  Future<Result<void>> verifyOtp({
    required String phoneNumber,
    required String otp,
  });

  /// Marks the invite as used, once the tenant record it describes has
  /// actually been created — not on OTP verification alone, so a verified
  /// but abandoned join doesn't burn the link.
  Future<Result<void>> consumeInvite(String token);
}
