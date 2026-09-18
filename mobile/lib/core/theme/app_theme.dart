import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';

/// Builds the app's light and dark [ThemeData] from the approved design's
/// tokens (`tokens-extra.css` — see [AppColors] for the source values).
///
/// This is the one place a `ColorScheme`/`TextTheme`/component theme is
/// assembled; screens should never construct their own `TextStyle` with a
/// hardcoded color or a bespoke button shape.
abstract final class AppTheme {
  static ThemeData get light => _build(brightness: Brightness.light);
  static ThemeData get dark => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final appColors = isDark ? AppColors.dark : AppColors.light;

    const accent = Color(0xFF4F46E5);
    const accentDark = Color(0xFF818CF8);
    const bgLight = Color(0xFFE7ECF3);
    const bgDark = Color(0xFF09090B);
    const surfaceLight = Color(0xFFFFFFFF);
    const surfaceDark = Color(0xFF111113);
    const textLight = Color(0xFF0F172A);
    const textDark = Color(0xFFFAFAFA);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? accentDark : accent,
      onPrimary: isDark ? const Color(0xFF1E1B4B) : Colors.white,
      secondary: isDark ? accentDark : accent,
      onSecondary: isDark ? const Color(0xFF1E1B4B) : Colors.white,
      error: appColors.danger,
      onError: Colors.white,
      surface: isDark ? surfaceDark : surfaceLight,
      onSurface: isDark ? textDark : textLight,
      surfaceContainerHighest: appColors.surfaceAlt,
      outline: appColors.divider,
      outlineVariant: appColors.dividerStrong,
    );

    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    final headingTextTheme = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    final textTheme = baseTextTheme
        .copyWith(
          displayLarge: headingTextTheme.displayLarge,
          displayMedium: headingTextTheme.displayMedium,
          displaySmall: headingTextTheme.displaySmall,
          headlineLarge: headingTextTheme.headlineLarge,
          headlineMedium: headingTextTheme.headlineMedium,
          headlineSmall: headingTextTheme.headlineSmall,
          titleLarge: headingTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          titleMedium: headingTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? bgDark : bgLight,
      textTheme: textTheme,
      dividerColor: appColors.divider,
      splashFactory: InkRipple.splashFactory,
      extensions: [appColors],
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? surfaceDark : surfaceLight,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: isDark ? surfaceDark : surfaceLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: appColors.divider),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.45),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: appColors.divider),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceDark : surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: appColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: appColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: appColors.textSecondary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? surfaceDark : surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? surfaceDark : surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}
