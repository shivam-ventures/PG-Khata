import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/user_role.dart';
import '../domain/public_property_listing.dart';
import '../domain/tenant_invite.dart';
import 'onboarding_repository.dart';

/// Real backend for [OnboardingRepository].
///
/// `resolveInvite` calls the `resolve-invite` Edge Function (service role)
/// rather than querying `tenant_invite_links` directly — that table
/// deliberately has no anon RLS policy (`docs/backend-domain-model.md`
/// §9/§12.4), since an invite link must be resolvable by someone who isn't
/// signed in yet.
///
/// `sendOtp`/`verifyOtp` talk to Supabase Auth directly, the same as
/// [SupabaseAuthRepository] but *without* its profile lookup — at this
/// point nobody has a `profiles` row yet, that's what `completeJoin`
/// creates, atomically, via the `complete_invite_join` RPC.
class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<TenantInvite>> resolveInvite(String token) async {
    try {
      final response = await _client.functions.invoke(
        'resolve-invite',
        body: {'token': token},
      );
      final data = response.data as Map<String, dynamic>;
      return Ok(
        TenantInvite(
          token: data['token'] as String,
          propertyName: data['propertyName'] as String,
          room: data['room'] as String,
          bed: data['bed'] as String,
          rentPerBed: (data['rentPerBed'] as num).round(),
          managerName: data['managerName'] as String,
        ),
      );
    } on FunctionException catch (e) {
      final error = e.details is Map
          ? (e.details as Map)['error'] as String?
          : null;
      return switch (error) {
        'invite_already_used' => const Err(InviteAlreadyUsedFailure()),
        'invite_expired' => const Err(InviteExpiredFailure()),
        _ => const Err(InviteNotFoundFailure()),
      };
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> sendOtp(String phoneNumber) async {
    try {
      await _client.auth.signInWithOtp(phone: _toE164(phoneNumber));
      return const Ok(null);
    } on AuthException {
      return const Err(NetworkFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      await _client.auth.verifyOTP(
        type: OtpType.sms,
        phone: _toE164(phoneNumber),
        token: otp,
      );
      return const Ok(null);
    } on AuthException {
      return const Err(InvalidOtpFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<AppUser>> completeJoin({
    required String token,
    required String fullName,
    required String phoneNumber,
  }) async {
    try {
      await _client.rpc(
        'complete_invite_join',
        params: {'p_token': token, 'p_full_name': fullName},
      );
      final userId = _client.auth.currentUser!.id;
      return Ok(
        AppUser(
          id: userId,
          name: fullName,
          phone: _bareDigits(phoneNumber),
          role: UserRole.tenant,
        ),
      );
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<String>> createInviteLink(String bedId) async {
    try {
      final created = await _client.rpc(
        'create_invite_link',
        params: {'p_bed_id': bedId},
      );
      return Ok((created as Map<String, dynamic>)['token'] as String);
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<List<PublicPropertyListing>>> fetchPublicProperties() async {
    try {
      final rows = await _client
          .from('public_property_listings')
          .select()
          .order('name');
      return Ok([
        for (final row in rows)
          PublicPropertyListing(
            propertyId: row['property_id'] as String,
            name: row['name'] as String,
            address: row['address'] as String,
            vacantBedCount: (row['vacant_bed_count'] as num).round(),
          ),
      ]);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<AppUser>> selfRegister({
    required String fullName,
    required String propertyId,
    required String phoneNumber,
  }) async {
    try {
      await _client.rpc(
        'self_register_tenant',
        params: {'p_full_name': fullName, 'p_property_id': propertyId},
      );
      final userId = _client.auth.currentUser!.id;
      return Ok(
        AppUser(
          id: userId,
          name: fullName,
          phone: _bareDigits(phoneNumber),
          role: UserRole.tenant,
        ),
      );
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  /// The app collects a bare 10-digit Indian mobile number; Supabase auth
  /// needs E.164.
  String _toE164(String phoneNumber) =>
      phoneNumber.startsWith('+') ? phoneNumber : '+91$phoneNumber';

  String _bareDigits(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }
}
