import 'package:flutter/material.dart';

/// Semantic color tokens ported from `tokens-extra.css` — the v2 SaaS color
/// layer the approved screens actually render with (see that file's `:root`
/// and `[data-theme='dark']` blocks for the source values).
///
/// [ColorScheme] alone can't express this design's exact vocabulary (a
/// separate "surface" vs. "surface-alt", a muted vs. secondary text color,
/// soft 100-tint / 700-text semantic pairs for success/warning/danger/info).
/// This extension carries those tokens verbatim so widgets read
/// `Theme.of(context).appColors.xxx` instead of hand-picking a color.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surfaceAlt,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.dividerStrong,
    required this.accent100,
    required this.accent700,
    required this.success,
    required this.success100,
    required this.success700,
    required this.warning,
    required this.warning100,
    required this.warning700,
    required this.danger,
    required this.danger100,
    required this.danger700,
    required this.info,
    required this.info100,
    required this.info700,
  });

  final Color surfaceAlt;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;
  final Color dividerStrong;

  final Color accent100;
  final Color accent700;

  final Color success;
  final Color success100;
  final Color success700;

  final Color warning;
  final Color warning100;
  final Color warning700;

  final Color danger;
  final Color danger100;
  final Color danger700;

  final Color info;
  final Color info100;
  final Color info700;

  static const light = AppColors(
    surfaceAlt: Color(0xFFEEF2F7),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    divider: Color(0xFFE2E8F0),
    dividerStrong: Color(0xFFCBD5E1),
    accent100: Color(0xFFEEF2FF),
    accent700: Color(0xFF3730A3),
    success: Color(0xFF16A34A),
    success100: Color(0xFFF0FDF4),
    success700: Color(0xFF166534),
    warning: Color(0xFFD97706),
    warning100: Color(0xFFFFFBEB),
    warning700: Color(0xFF92400E),
    danger: Color(0xFFDC2626),
    danger100: Color(0xFFFEF2F2),
    danger700: Color(0xFF991B1B),
    info: Color(0xFF2563EB),
    info100: Color(0xFFEFF6FF),
    info700: Color(0xFF1E40AF),
  );

  static const dark = AppColors(
    surfaceAlt: Color(0xFF18181B),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    divider: Color(0xFF27272A),
    dividerStrong: Color(0xFF3F3F46),
    accent100: Color(0xFF1E1B4B),
    accent700: Color(0xFFC7D2FE),
    success: Color(0xFF4ADE80),
    success100: Color(0xFF052E16),
    success700: Color(0xFF86EFAC),
    warning: Color(0xFFFBBF24),
    warning100: Color(0xFF451A03),
    warning700: Color(0xFFFCD34D),
    danger: Color(0xFFF87171),
    danger100: Color(0xFF450A0A),
    danger700: Color(0xFFFCA5A5),
    info: Color(0xFF60A5FA),
    info100: Color(0xFF1E3A5F),
    info700: Color(0xFF93C5FD),
  );

  @override
  AppColors copyWith({
    Color? surfaceAlt,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? dividerStrong,
    Color? accent100,
    Color? accent700,
    Color? success,
    Color? success100,
    Color? success700,
    Color? warning,
    Color? warning100,
    Color? warning700,
    Color? danger,
    Color? danger100,
    Color? danger700,
    Color? info,
    Color? info100,
    Color? info700,
  }) {
    return AppColors(
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      dividerStrong: dividerStrong ?? this.dividerStrong,
      accent100: accent100 ?? this.accent100,
      accent700: accent700 ?? this.accent700,
      success: success ?? this.success,
      success100: success100 ?? this.success100,
      success700: success700 ?? this.success700,
      warning: warning ?? this.warning,
      warning100: warning100 ?? this.warning100,
      warning700: warning700 ?? this.warning700,
      danger: danger ?? this.danger,
      danger100: danger100 ?? this.danger100,
      danger700: danger700 ?? this.danger700,
      info: info ?? this.info,
      info100: info100 ?? this.info100,
      info700: info700 ?? this.info700,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dividerStrong: Color.lerp(dividerStrong, other.dividerStrong, t)!,
      accent100: Color.lerp(accent100, other.accent100, t)!,
      accent700: Color.lerp(accent700, other.accent700, t)!,
      success: Color.lerp(success, other.success, t)!,
      success100: Color.lerp(success100, other.success100, t)!,
      success700: Color.lerp(success700, other.success700, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warning100: Color.lerp(warning100, other.warning100, t)!,
      warning700: Color.lerp(warning700, other.warning700, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      danger100: Color.lerp(danger100, other.danger100, t)!,
      danger700: Color.lerp(danger700, other.danger700, t)!,
      info: Color.lerp(info, other.info, t)!,
      info100: Color.lerp(info100, other.info100, t)!,
      info700: Color.lerp(info700, other.info700, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  /// Shorthand for the app's semantic color tokens: `context.appColors.textMuted`.
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
