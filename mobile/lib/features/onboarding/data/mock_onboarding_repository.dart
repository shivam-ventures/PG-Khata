import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/tenant_invite.dart';
import 'onboarding_repository.dart';

/// Phase-2 mock backing for [OnboardingRepository]. Seeded with tokens for
/// HSR PG's actually-vacant beds (see `MockRoomsRepository`), in the same
/// `propertyId-room-bed` shape Manager Rooms' "Invite via link" dialog
/// already builds — so a link generated there resolves here.
class MockOnboardingRepository implements OnboardingRepository {
  static const _validOtp = '123456';

  static const _invitesByToken = <String, TenantInvite>{
    'hsr-101-C': TenantInvite(
      token: 'hsr-101-C',
      propertyId: 'hsr',
      propertyName: 'HSR PG',
      room: '101',
      bed: 'C',
      rentPerBed: 6500,
      managerName: 'Ramesh K.',
    ),
    'hsr-201-B': TenantInvite(
      token: 'hsr-201-B',
      propertyId: 'hsr',
      propertyName: 'HSR PG',
      room: '201',
      bed: 'B',
      rentPerBed: 6500,
      managerName: 'Ramesh K.',
    ),
    'hsr-201-C': TenantInvite(
      token: 'hsr-201-C',
      propertyId: 'hsr',
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
  Future<Result<void>> consumeInvite(String token) async {
    _consumedTokens.add(token);
    return const Ok(null);
  }
}
