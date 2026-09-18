/// Spacing scale, ported from the approved design's `--space-*` tokens
/// (`design/design_handoff_pg_khata_app/screens/_ds/modernist-*/styles.css`).
///
/// Screens should always reach for one of these instead of a raw number, so
/// the rhythm of the app stays centralized in one place.
abstract final class AppSpacing {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;
}
