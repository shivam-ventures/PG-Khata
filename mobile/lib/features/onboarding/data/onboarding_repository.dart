import '../../../core/errors/result.dart';
import '../../auth/domain/app_user.dart';
import '../domain/public_property_listing.dart';
import '../domain/tenant_invite.dart';

/// The invite-link entry point from `Auth.dc.html`'s `hasInvite` branch:
/// resolve a bed-specific token, then verify the invited person's phone —
/// this *is* their first real login, per `docs/DECISIONS.md`'s 2026-09-15
/// onboarding entry. [MockOnboardingRepository] backs this for isolated UI
/// dev/tests; [SupabaseOnboardingRepository] is the real backend.
abstract interface class OnboardingRepository {
  Future<Result<TenantInvite>> resolveInvite(String token);

  Future<Result<void>> sendOtp(String phoneNumber);

  Future<Result<void>> verifyOtp({
    required String phoneNumber,
    required String otp,
  });

  /// Completes the join once the invited person has verified their phone
  /// and confirmed their name: creates their profile, fills the invited
  /// bed, and burns the invite link — atomically, so a verified-but-
  /// abandoned join can never leave a bed half-claimed. Returns the
  /// signed-in [AppUser] on success.
  Future<Result<AppUser>> completeJoin({
    required String token,
    required String fullName,
    required String phoneNumber,
  });

  /// A Manager/Owner generating a bed-specific link to share — returns the
  /// invite token `resolveInvite`/`completeJoin` above expect at `/join/:token`.
  Future<Result<String>> createInviteLink(String bedId);

  /// Every PG with at least a listing, for direct self-registration's
  /// "pick a PG" step — reachable while signed out, so this is a public
  /// read, not scoped to any org.
  Future<Result<List<PublicPropertyListing>>> fetchPublicProperties();

  /// Direct self-registration, once the person has verified their phone
  /// and confirmed their name: creates their profile and records which PG
  /// they want to join, landing them in the Owner/Manager Tenants screens'
  /// "self-registered — needs a bed" list rather than an active tenancy —
  /// staff still picks the actual bed and rent, unlike [completeJoin].
  /// Returns the signed-in [AppUser] on success, same as [completeJoin].
  Future<Result<AppUser>> selfRegister({
    required String fullName,
    required String propertyId,
    required String phoneNumber,
  });
}
