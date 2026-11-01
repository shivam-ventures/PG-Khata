import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/user_role.dart';
import '../domain/public_property_listing.dart';
import '../domain/tenant_invite.dart';
import 'onboarding_repository.dart';

/// Mock backing for [OnboardingRepository], for isolated UI dev/tests —
/// superseded by [SupabaseOnboardingRepository] as the default. Seeded with
/// tokens for HSR PG's actually-vacant beds (see `MockRoomsRepository`), in
/// the same `propertyId-room-bed` shape Manager Rooms' "Invite via link"
/// dialog builds in mock mode — so a link generated there resolves here.
class MockOnboardingRepository implements OnboardingRepository {
  static const _validOtp = '123456';

  static const _invitesByToken = <String, TenantInvite>{
    'hsr-101-C': TenantInvite(
      token: 'hsr-101-C',
      propertyName: 'HSR PG',
      room: '101',
      bed: 'C',
      rentPerBed: 6500,
      managerName: 'Ramesh K.',
    ),
    'hsr-201-B': TenantInvite(
      token: 'hsr-201-B',
      propertyName: 'HSR PG',
      room: '201',
      bed: 'B',
      rentPerBed: 6500,
      managerName: 'Ramesh K.',
    ),
    'hsr-201-C': TenantInvite(
      token: 'hsr-201-C',
      propertyName: 'HSR PG',
      room: '201',
      bed: 'C',
      rentPerBed: 6500,
      managerName: 'Ramesh K.',
    ),
  };

  final Set<String> _consumedTokens = {};

  @override
  Future<Result<TenantInvite>> resolveInvite(String token) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_consumedTokens.contains(token)) {
      return const Err(InviteAlreadyUsedFailure());
    }
    final invite = _invitesByToken[token];
    if (invite == null) {
      return const Err(InviteNotFoundFailure());
    }
    return Ok(invite);
  }

  @override
  Future<Result<void>> sendOtp(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const Ok(null);
  }

  @override
  Future<Result<void>> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (otp != _validOtp) {
      return const Err(InvalidOtpFailure());
    }
    return const Ok(null);
  }

  @override
  Future<Result<AppUser>> completeJoin({
    required String token,
    required String fullName,
    required String phoneNumber,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _consumedTokens.add(token);
    return Ok(
      AppUser(
        id: 't${DateTime.now().microsecondsSinceEpoch}',
        name: fullName,
        phone: phoneNumber,
        role: UserRole.tenant,
      ),
    );
  }

  @override
  Future<Result<String>> createInviteLink(String bedId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Mock bed ids are already in the `propertyId-room-bed` shape
    // `_invitesByToken` is keyed by, so the id doubles as the token here.
    return Ok(bedId);
  }

  static const _properties = [
    PublicPropertyListing(
      propertyId: 'hsr',
      name: 'HSR PG',
      address: 'HSR Layout, Bengaluru',
      vacantBedCount: 3,
    ),
  ];

  @override
  Future<Result<List<PublicPropertyListing>>> fetchPublicProperties() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const Ok(_properties);
  }

  @override
  Future<Result<AppUser>> selfRegister({
    required String fullName,
    required String propertyId,
    required String phoneNumber,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Ok(
      AppUser(
        id: 't${DateTime.now().microsecondsSinceEpoch}',
        name: fullName,
        phone: phoneNumber,
        role: UserRole.tenant,
      ),
    );
  }
}
