import 'package:flutter/widgets.dart';

/// Elevation shadows, ported from `tokens-extra.css`'s `--shadow-*` tokens.
///
/// Values differ between light and dark mode in the source design (an
/// ink-tinted shadow on light, a heavier black shadow on dark), so callers
/// should pull these from [AppShadows.of] rather than a bare static list.
abstract final class AppShadows {
  static List<BoxShadow> of(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  static const List<BoxShadow> _light = [
    BoxShadow(color: Color(0x0F0F172A), offset: Offset(0, 1), blurRadius: 2),
  ];

  static const List<BoxShadow> _dark = [
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  static List<BoxShadow> mdOf(Brightness brightness) =>
      brightness == Brightness.dark ? _mdDark : _mdLight;

  static const List<BoxShadow> _mdLight = [
    BoxShadow(color: Color(0x140F172A), offset: Offset(0, 4), blurRadius: 16),
  ];

  static const List<BoxShadow> _mdDark = [
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 4), blurRadius: 16),
  ];
}
