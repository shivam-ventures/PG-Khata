import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'semantic_tone.dart';

/// The `.qa-btn` pattern repeated across all three role homes: a colored
/// icon badge over a short label, laid out in a row. Each screen supplies
/// its own list of quick actions; this widget only renders one tile.
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final SemanticTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.space3,
            horizontal: 2,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: context.appColors.divider),
            borderRadius: AppRadius.mdAll,
            boxShadow: AppShadows.of(theme.brightness),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tone.background(context),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, size: 18, color: tone.foreground(context)),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppTextStyles.tagLabel.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
