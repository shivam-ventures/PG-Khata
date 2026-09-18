import 'package:flutter/material.dart';

/// Shows a brief "coming in Phase X" notice for a tap that targets a feature
/// with no route of its own yet (e.g. a quick action for a screen that isn't
/// one of the current role's bottom-nav tabs). Destinations that do have a
/// tab (Properties, Payments, ...) should navigate there instead of calling
/// this — see each screen's own routing for which is which.
void notifyNotBuiltYet(
  BuildContext context, {
  required String feature,
  required String phase,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature is coming in $phase.')));
}
