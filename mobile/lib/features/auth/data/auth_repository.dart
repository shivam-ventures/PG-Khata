import '../../../core/errors/result.dart';
import '../domain/app_user.dart';

/// Auth operations the UI needs, independent of how they're actually
/// fulfilled. [MockAuthRepository] backs this in Phase 0; a
/// `SupabaseAuthRepository` implementing the same interface is a Phase 6
/// swap behind [authRepositoryProvider] — nothing above this layer changes.
abstract interface class AuthRepository {
  /// Dispatches an OTP to [phoneNumber]. In production this triggers a real
  /// SMS; the mock implementation only simulates the delay.
  Future<Result<void>> sendOtp(String phoneNumber);

  /// Verifies [otp] for [phoneNumber] and returns the resolved [AppUser] on
  /// success, or an [AppFailure] (e.g. [InvalidOtpFailure]) on a wrong code.
  Future<Result<AppUser>> verifyOtp({
    required String phoneNumber,
    required String otp,
  });

  /// Ends the current session.
  Future<void> signOut();

  /// Restores the signed-in user from an already-active session (e.g. on
  /// app restart), or `null` if there isn't one.
  Future<AppUser?> restoreSession();

  /// Updates whichever of the signed-in user's Settings-screen preferences
  /// are given, leaving the rest untouched.
  Future<Result<AppUser>> updatePreferences({
    String? preferredLanguage,
    bool? notifyComplaints,
    bool? notifyAnnouncements,
  });
}
