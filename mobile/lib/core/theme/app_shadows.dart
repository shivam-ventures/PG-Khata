import 'package:flutter/widgets.dart';

/// Elevation shadows, ported from `tokens-extra.css`'s `--shadow-*` tokens.
///
/// Values differ between light and dark mode in the source design. Light
/// mode uses an ink-tinted drop shadow, which reads fine against its pale
/// background. A dark drop shadow doesn't work the same way on this app's
/// near-black dark surfaces (`AppTheme`'s `bgDark`/`surfaceDark` sit only a
/// few units apart) — a black-on-near-black shadow is indistinguishable
/// from the background, so elevated cards read as flat. Dark mode instead
/// uses a faint light-based shadow, which shows up as a subtle rim/glow —
/// the standard substitute for a drop shadow on a near-black canvas.
/// Callers should pull these from [AppShadows.of] rather than a bare list.
abstract final class AppShadows {
  static List<BoxShadow> of(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  static const List<BoxShadow> _light = [
    BoxShadow(color: Color(0x0F0F172A), offset: Offset(0, 1), blurRadius: 2),
  ];

  static const List<BoxShadow> _dark = [
    BoxShadow(color: Color(0x1AFFFFFF), offset: Offset(0, 1), blurRadius: 2),
  ];

  static List<BoxShadow> mdOf(Brightness brightness) =>
      brightness == Brightness.dark ? _mdDark : _mdLight;

  static const List<BoxShadow> _mdLight = [
    BoxShadow(color: Color(0x140F172A), offset: Offset(0, 4), blurRadius: 16),
  ];

  static const List<BoxShadow> _mdDark = [
    BoxShadow(color: Color(0x24FFFFFF), offset: Offset(0, 4), blurRadius: 16),
  ];
}
