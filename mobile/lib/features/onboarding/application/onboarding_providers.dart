import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/onboarding_repository.dart';
import '../data/supabase_onboarding_repository.dart';
import '../domain/public_property_listing.dart';
import '../domain/tenant_invite.dart';

/// The single override point for swapping the onboarding data source — was
/// `MockOnboardingRepository()` through Phase 2; now backed by real
/// Supabase auth + the `complete_invite_join` RPC.
final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => SupabaseOnboardingRepository(ref.watch(supabaseClientProvider)),
);

/// Resolves a `/join/:token` link to the bed it invites someone to.
final tenantInviteProvider = FutureProvider.family<TenantInvite, String>((
  ref,
  token,
) async {
  final result = await ref
      .watch(onboardingRepositoryProvider)
      .resolveInvite(token);
  return result.when(ok: (invite) => invite, err: (failure) => throw failure);
});

Future<AppFailure?> sendInviteOtp(WidgetRef ref, String phoneNumber) async {
  final result = await ref
      .read(onboardingRepositoryProvider)
      .sendOtp(phoneNumber);
  return result.when(ok: (_) => null, err: (failure) => failure);
}

Future<AppFailure?> verifyInviteOtp(
  WidgetRef ref, {
  required String phoneNumber,
  required String otp,
}) async {
  final result = await ref
      .read(onboardingRepositoryProvider)
      .verifyOtp(phoneNumber: phoneNumber, otp: otp);
  return result.when(ok: (_) => null, err: (failure) => failure);
}

/// Confirms the invited person's name, then completes their first real
/// login: creates their profile, fills the invited bed, burns the invite
/// link, and signs them straight into their new Tenant session — all
/// atomically, via [OnboardingRepository.completeJoin].
Future<AppFailure?> completeInviteJoin(
  WidgetRef ref, {
  required TenantInvite invite,
  required String name,
  required String phoneNumber,
}) async {
  final result = await ref
      .read(onboardingRepositoryProvider)
      .completeJoin(token: invite.token, fullName: name, phoneNumber: phoneNumber);
  return result.when(
    ok: (user) {
      ref.read(authControllerProvider.notifier).completeInviteSignIn(user);
      return null;
    },
    err: (failure) => failure,
  );
}

/// Every PG a "pick a PG" picker can offer for direct self-registration.
final publicPropertiesProvider = FutureProvider<List<PublicPropertyListing>>((
  ref,
) async {
  final result = await ref
      .watch(onboardingRepositoryProvider)
      .fetchPublicProperties();
  return result.when(ok: (v) => v, err: (failure) => throw failure);
});

/// Confirms a direct self-registration's name, then signs the person
/// straight into a Tenant session with no bed assigned yet — see
/// [OnboardingRepository.selfRegister]'s doc comment for how this differs
/// from [completeInviteJoin].
Future<AppFailure?> selfRegisterTenant(
  WidgetRef ref, {
  required String fullName,
  required String propertyId,
  required String phoneNumber,
}) async {
  final result = await ref
      .read(onboardingRepositoryProvider)
      .selfRegister(
        fullName: fullName,
        propertyId: propertyId,
        phoneNumber: phoneNumber,
      );
  return result.when(
    ok: (user) {
      ref.read(authControllerProvider.notifier).completeInviteSignIn(user);
      return null;
    },
    err: (failure) => failure,
  );
}
