import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'semantic_tone.dart';

/// The `.stat-card` pattern used on the Owner Dashboard's stat grid and the
/// Manager Today mini-stat row: an icon badge, a muted label, a large value,
/// and an optional meta line underneath.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.tone = SemanticTone.neutral,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final SemanticTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: context.appColors.divider),
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadows.of(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(bottom: AppSpacing.space1),
            decoration: BoxDecoration(
              color: tone.background(context),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, size: 18, color: tone.foreground(context)),
          ),
          Text(
            label,
            style: AppTextStyles.kicker.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.space1),
          Text(
            value,
            style: AppTextStyles.statValue.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: AppSpacing.space1),
            Text(
              sub!,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 11,
                color: context.appColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
