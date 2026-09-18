import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The design's recurring soft-fill / full-tone color pairing (see
/// `tokens-extra.css`'s `.tag-*` classes) — used by [StatusChip], [StatCard]'s
/// icon badge, and quick-action icon badges so a given meaning (success,
/// overdue, ...) always reads as the same color everywhere in the app.
enum SemanticTone { accent, success, warning, danger, info, neutral }

extension SemanticToneColors on SemanticTone {
  /// The soft background fill (the `-100` tint).
  Color background(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return switch (this) {
      SemanticTone.accent => colors.accent100,
      SemanticTone.success => colors.success100,
      SemanticTone.warning => colors.warning100,
      SemanticTone.danger => colors.danger100,
      SemanticTone.info => colors.info100,
      SemanticTone.neutral => scheme.surfaceContainerHighest,
    };
  }

  /// The full-tone foreground (the `-700` text-on-tint step).
  Color foreground(BuildContext context) {
    final colors = context.appColors;
    return switch (this) {
      SemanticTone.accent => colors.accent700,
      SemanticTone.success => colors.success700,
      SemanticTone.warning => colors.warning700,
      SemanticTone.danger => colors.danger700,
      SemanticTone.info => colors.info700,
      SemanticTone.neutral => colors.textSecondary,
    };
  }
}
