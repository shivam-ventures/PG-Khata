import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/session/logout_reset.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/app_user.dart';

/// The single override point for swapping auth backends — was
/// `MockAuthRepository()` through Phase 0/1; now backed by real Supabase
/// phone-OTP auth, with nothing else in the app changed.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

/// The current session — `null` means signed out. Screens read this instead
/// of the repository directly, and `go_router`'s redirect uses it to decide
/// whether a route is reachable (see `core/routing/app_router.dart`).
final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() {
    return ref.read(authRepositoryProvider).restoreSession();
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

  /// Signs out AND clears every user-scoped provider (see
  /// `core/session/logout_reset.dart`) — without the reset, a second user
  /// signing in on the same app instance could briefly see the previous
  /// user's cached properties/tenants/payments/etc., since none of those
  /// providers watch auth state on their own. Found during the pre-launch
  /// audit (2026-09-25).
  ///
  /// Order matters here: `state` is set FIRST, before the reset. Several
  /// user-scoped providers (ownerDashboardProvider, managerTodayProvider,
  /// tenantHomeProvider) watch `authControllerProvider.future` — if
  /// `resetUserScopedProviders` runs while this method (i.e. this
  /// provider's own update) is still in flight, invalidating one of their
  /// other dependencies can make a still-mounted screen (kept alive by the
  /// bottom nav's tab preservation) rebuild one of those immediately, which
  /// re-enters `authControllerProvider` while it's still being updated —
  /// a real `CircularDependencyError`, reproduced live on both a Manager
  /// and a Tenant account (2026-09-25). Completing the state update first
  /// means any such rebuild reads the new (signed-out) value instead of
  /// re-entering an in-progress one.
  Future<void> logout() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncValue.data(null);
    resetUserScopedProviders(ref);
  }

  /// Saves a Settings-screen change and reflects it in [state] immediately
  /// — the whole app (locale, notification-sending logic) reads preferences
  /// off this same [AppUser], never a separate "settings" provider.
  Future<AppFailure?> updatePreferences({
    String? preferredLanguage,
    bool? notifyComplaints,
    bool? notifyAnnouncements,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .updatePreferences(
          preferredLanguage: preferredLanguage,
          notifyComplaints: notifyComplaints,
          notifyAnnouncements: notifyAnnouncements,
        );
    return result.when(
      ok: (user) {
        state = AsyncValue.data(user);
        return null;
      },
      err: (failure) => failure,
    );
  }

  /// Signs [user] straight in without a phone/OTP round-trip of its own —
  /// for the invite-link join flow (`features/onboarding`), where phone
  /// verification already happened against the invite itself and this *is*
  /// the tenant's first real login, per `docs/DECISIONS.md`'s 2026-09-15
  /// onboarding entry.
  void completeInviteSignIn(AppUser user) {
    state = AsyncValue.data(user);
  }
}
