import 'package:flutter/widgets.dart';

/// Corner-radius scale, ported from `tokens-extra.css`'s `--radius-*`
/// overrides (the v2 SaaS layer the approved screens actually render with —
/// not the base Modernist system's 0px radii).
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}
