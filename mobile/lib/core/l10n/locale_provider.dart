import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';

/// The app-wide UI language — derived from the signed-in user's own
/// [AppUser.preferredLanguage] rather than tracked separately, so it's
/// always in sync with what Settings just saved and never drifts across a
/// login/logout. Defaults to English before anyone's signed in.
final localeProvider = Provider<Locale>((ref) {
  final user = ref.watch(authControllerProvider).value;
  return Locale(user?.preferredLanguage ?? 'en');
});
