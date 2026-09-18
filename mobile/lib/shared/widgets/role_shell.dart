import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_scaffold.dart';
import 'role_bottom_nav.dart';

/// The per-role app shell: one `Scaffold` (via [AppScaffold]) wrapping a
/// `go_router` [StatefulNavigationShell] and a [RoleBottomNav] built from
/// [items]. Each branch's own screen renders only its page content, not a
/// `Scaffold` of its own — this is the one place the outer chrome lives.
class RoleShell extends StatelessWidget {
  const RoleShell({
    required this.navigationShell,
    required this.items,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavItem> items;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: navigationShell,
      bottomNavigationBar: RoleBottomNav(
        items: items,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
