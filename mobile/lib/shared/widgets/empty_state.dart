import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// A short encouraging line plus the one action that fills it — the design's
/// `<EmptyState>` rule: never a bare "No data" label with nothing to do next.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space6,
        vertical: AppSpacing.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.appColors.accent100,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, size: 24, color: context.appColors.accent700),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 19),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            message,
            style: AppTextStyles.body.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          if (primaryActionLabel != null) ...[
            const SizedBox(height: AppSpacing.space4),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: primaryActionLabel!,
                onPressed: onPrimaryAction,
              ),
            ),
          ],
          if (secondaryActionLabel != null) ...[
            const SizedBox(height: AppSpacing.space2),
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                label: secondaryActionLabel!,
                onPressed: onSecondaryAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
