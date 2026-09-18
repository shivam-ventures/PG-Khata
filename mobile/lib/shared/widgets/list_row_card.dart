import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// The `.list-card` pattern: a title/subtitle pair, a trailing widget (a
/// status chip, an amount, a button), and an optional overflow action —
/// used for tenant rows, payment history rows, and similar lists.
class ListRowCard extends StatelessWidget {
  const ListRowCard({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onOverflow,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onOverflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: context.appColors.divider),
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadows.of(theme.brightness),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.rowTitle,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.appColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.space2),
            trailing!,
          ],
          if (onOverflow != null)
            IconButton(
              icon: const Icon(Icons.more_vert, size: 18),
              tooltip: 'More actions',
              onPressed: onOverflow,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}
