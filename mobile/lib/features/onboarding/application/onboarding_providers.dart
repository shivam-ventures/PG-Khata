import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/user_role.dart';
import '../../rooms/application/rooms_providers.dart';
import '../../tenants/application/tenants_providers.dart';
import '../../tenants/domain/tenant_status.dart';
import '../data/mock_onboarding_repository.dart';
import '../data/onboarding_repository.dart';
import '../domain/tenant_invite.dart';

/// The single override point for swapping the onboarding data source: point
/// this at a Supabase-backed implementation in Phase 6.
final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => MockOnboardingRepository(),
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

/// Confirms the invited person's name, then does everything their first
/// real login needs to do: creates their tenant record, fills the bed they
/// were invited to, burns the invite link, and signs them straight into
/// their new Tenant session — matching `Auth.dc.html`'s "You're in" step.
Future<AppFailure?> completeInviteJoin(
  WidgetRef ref, {
  required TenantInvite invite,
  required String name,
  required String phoneNumber,
}) async {
  final addFailure = await addTenant(
    ref,
    name: name,
    phone: phoneNumber,
    propertyId: invite.propertyId,
    propertyName: invite.propertyName,
    roomBed: '${invite.room} - ${invite.bed}',
    rent: invite.rentPerBed,
    joinedDate: DateTime.now(),
    status: TenantStatus.active,
  );
  if (addFailure != null) return addFailure;

  await occupyBed(
    ref,
    invite.propertyId,
    room: invite.room,
    bed: invite.bed,
    tenantName: name,
  );
  await ref.read(onboardingRepositoryProvider).consumeInvite(invite.token);

  ref
      .read(authControllerProvider.notifier)
      .completeInviteSignIn(
        AppUser(
          id: 't${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          phone: phoneNumber,
          role: UserRole.tenant,
        ),
      );
  return null;
}
