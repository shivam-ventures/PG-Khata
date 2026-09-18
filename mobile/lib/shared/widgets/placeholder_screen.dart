import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'empty_state.dart';

/// Stands in for a feature not yet built (Properties, Payments, Rooms, ...).
/// Keeps every nav destination reachable in Phase 0 without building the
/// feature itself ahead of its scheduled phase — see `docs/DECISIONS.md`'s
/// phase plan for when each of these actually lands.
///
/// Rendered inside a role's [RoleShell], which already provides the outer
/// `Scaffold`/bottom-nav/mobile-shell width — this only needs to be page
/// content, not a screen in its own right.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.comingInPhase,
    super.key,
  });

  final String title;
  final String comingInPhase;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 19),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: EmptyState(
              icon: Icons.construction_outlined,
              title: 'Coming in $comingInPhase',
              message:
                  "$title isn't built yet — this is a placeholder so navigation stays whole.",
            ),
          ),
        ),
      ],
    );
  }
}
