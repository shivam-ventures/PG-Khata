import 'package:flutter/material.dart';

/// The shared mobile-shell wrapper: the approved design constrains every
/// screen to a 480px-wide centered column (`max-width:480px;margin:0 auto`)
/// even though it's built mobile-first — on a phone this is a no-op, on a
/// wider device (a tablet, a desktop test window) it keeps the layout from
/// stretching into an unintended responsive redesign.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.bottomNavigationBar,
    this.backgroundColor,
    super.key,
  });

  final Widget body;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  static const double maxShellWidth = 480;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: bottomNavigationBar == null,
        child: _CenteredWidth(child: body),
      ),
      bottomNavigationBar: bottomNavigationBar == null
          ? null
          : SafeArea(
              top: false,
              child: _CenteredWidth(child: bottomNavigationBar!),
            ),
    );
  }
}

/// Caps [child] at [AppScaffold.maxShellWidth] and centers it horizontally,
/// via symmetric padding rather than `Center`/`Align`.
///
/// `Center`/`Align` shrink-wrap to their child's size whenever the incoming
/// constraints are height-unbounded (a real case here: a `go_router`
/// `StatefulShellRoute` page can hand its content unbounded height during a
/// branch transition) — collapsing the whole screen to its shortest child
/// and centering *that* in the viewport instead of filling it. `Padding`
/// only deflates the constraints it passes down, so `body` always keeps
/// filling whatever height it's actually given, bounded or not.
class _CenteredWidth extends StatelessWidget {
  const _CenteredWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = constraints.maxWidth > AppScaffold.maxShellWidth
            ? (constraints.maxWidth - AppScaffold.maxShellWidth) / 2
            : 0.0;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: child,
        );
      },
    );
  }
}
