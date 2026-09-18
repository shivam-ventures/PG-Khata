import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../data/auth_repository.dart';
import '../data/mock_auth_repository.dart';
import '../domain/app_user.dart';

/// The single override point for swapping auth backends: point this at a
/// `SupabaseAuthRepository` in Phase 6 and nothing else in the app changes.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(),
);

/// The current session — `null` means signed out. Screens read this instead
/// of the repository directly, and `go_router`'s redirect uses it to decide
/// whether a route is reachable (see `core/routing/app_router.dart`).
final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    // No persisted session in Phase 0 (mock auth, nothing to restore from).
    // A real implementation checks a stored Supabase session here.
    return null;
  }

  Future<Result<void>> sendOtp(String phoneNumber) {
    return ref.read(authRepositoryProvider).sendOtp(phoneNumber);
  }

  /// Verifies the OTP and, on success, updates [state] to the signed-in
  /// user. Returns the failure on a wrong/expired code so the OTP screen can
  /// show it inline, without ever putting the controller into an error state
  /// over something as routine as a mistyped digit.
  Future<AppFailure?> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .verifyOtp(phoneNumber: phoneNumber, otp: otp);
    return result.when(
      ok: (user) {
        state = AsyncValue.data(user);
        return null;
      },
      err: (failure) => failure,
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncValue.data(null);
  }
}
