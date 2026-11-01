import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/app_user.dart';
import '../domain/user_role.dart';
import 'auth_repository.dart';

/// Real backend for [AuthRepository]: Supabase phone-OTP auth plus the
/// `profiles` table. Unlike [MockAuthRepository]'s "unknown number = new
/// tenant" shortcut (a mock-only affordance, see
/// `docs/backend-ui-data-audit.md`), a verified phone with no matching
/// `profiles` row is a real failure here — real accounts are created by
/// seeding, the join-invite flow, or a staff "Add tenant" action, never by
/// signing in.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<void>> sendOtp(String phoneNumber) async {
    try {
      await _client.auth.signInWithOtp(phone: _toE164(phoneNumber));
      return const Ok(null);
    } on AuthException catch (e) {
      if (_isRateLimited(e)) return const Err(RateLimitedFailure());
      return const Err(NetworkFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<AppUser>> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        type: OtpType.sms,
        phone: _toE164(phoneNumber),
        token: otp,
      );
      final userId = response.user?.id;
      if (userId == null) return const Err(InvalidOtpFailure());

      final user = await _loadProfile(userId);
      if (user == null) {
        await _client.auth.signOut();
        return const Err(AccountNotFoundFailure());
      }
      return Ok(user);
    } on AuthException catch (e) {
      if (_isRateLimited(e)) return const Err(RateLimitedFailure());
      if (e.code == 'otp_expired') return const Err(OtpExpiredFailure());
      return const Err(InvalidOtpFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  /// Supabase Auth's own rate limiting on OTP send/verify — distinguished
  /// by `code` (present on most API responses) with a `statusCode` 429
  /// fallback for the rare case a response arrives with no parsed code.
  /// See gotrue's `ErrorCode` for the full list this checks against.
  bool _isRateLimited(AuthException e) =>
      e.code == 'over_sms_send_rate_limit' ||
      e.code == 'over_request_rate_limit' ||
      e.statusCode == '429';

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<AppUser?> restoreSession() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return _loadProfile(userId);
  }

  @override
  Future<Result<AppUser>> updatePreferences({
    String? preferredLanguage,
    bool? notifyComplaints,
    bool? notifyAnnouncements,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Err(UnexpectedFailure());
    try {
      await _client
          .from('profiles')
          .update({
            if (preferredLanguage != null)
              'preferred_language': preferredLanguage,
            if (notifyComplaints != null) 'notify_complaints': notifyComplaints,
            if (notifyAnnouncements != null)
              'notify_announcements': notifyAnnouncements,
          })
          .eq('id', userId);
      final user = await _loadProfile(userId);
      if (user == null) return const Err(UnexpectedFailure());
      return Ok(user);
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  Future<AppUser?> _loadProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AppUser(
      id: row['id'] as String,
      name: row['full_name'] as String,
      phone: row['phone'] as String,
      role: UserRole.values.byName(row['role'] as String),
      preferredLanguage: row['preferred_language'] as String? ?? 'en',
      notifyComplaints: row['notify_complaints'] as bool? ?? true,
      notifyAnnouncements: row['notify_announcements'] as bool? ?? true,
    );
  }

  /// The app collects a bare 10-digit Indian mobile number; Supabase auth
  /// needs E.164.
  String _toE164(String phoneNumber) =>
      phoneNumber.startsWith('+') ? phoneNumber : '+91$phoneNumber';
}
