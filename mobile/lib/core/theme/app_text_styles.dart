import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Named text styles for the specific sizes the approved design uses that
/// don't map cleanly onto Material's fixed [TextTheme] slots (a 34px rent
/// figure, a 22px stat value, an 11px uppercase tag label, ...).
///
/// These carry no color — callers apply one via `.copyWith(color: ...)` or
/// let it inherit from an ambient [DefaultTextStyle], keeping light/dark
/// theming centralized in [AppColors] rather than baked into a style here.
abstract final class AppTextStyles {
  /// Sticky-header screen title, e.g. "Good morning, Anita" (h2 override).
  static TextStyle get screenTitle => GoogleFonts.manrope(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Section headings within a screen, e.g. "Properties", "Rent to collect" (h4).
  static TextStyle get sectionHeading => GoogleFonts.manrope(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  /// Card titles, e.g. a property name on the Owner Dashboard.
  static TextStyle get cardTitle => GoogleFonts.manrope(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  /// Large numeric callouts, e.g. a StatCard's "86%" / "₹4.1L".
  static TextStyle get statValue => GoogleFonts.manrope(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.0,
  );

  /// The largest numeric display on screen — the Tenant Home rent amount.
  static TextStyle get displayAmount => GoogleFonts.manrope(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );

  /// Small muted labels above a value, e.g. "Occupancy" above a stat.
  static TextStyle get kicker =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2);

  /// Uppercase, letter-spaced micro-label (h6 in the source design).
  static TextStyle get kickerUppercase => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    height: 1.2,
  );

  /// Default body copy.
  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5);

  /// Secondary/meta copy, e.g. a room number under a tenant's name.
  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4);

  /// Row labels inside compact cards (list-card / task-card titles).
  static TextStyle get rowTitle =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3);

  /// Status-chip / tag label text.
  static TextStyle get tagLabel => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Primary/secondary button label.
  static TextStyle get buttonLabel => GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}
