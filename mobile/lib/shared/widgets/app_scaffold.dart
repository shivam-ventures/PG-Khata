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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxShellWidth),
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: bottomNavigationBar == null
          ? null
          : SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxShellWidth),
                  child: bottomNavigationBar,
                ),
              ),
            ),
    );
  }
}
