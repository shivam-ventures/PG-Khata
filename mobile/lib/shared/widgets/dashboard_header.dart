import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'theme_toggle_button.dart';

/// The sticky header shared by the Owner Dashboard and Manager Today: a
/// muted date label over a greeting, with the settings and theme-toggle
/// icons trailing.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.dateLabel,
    required this.greeting,
    this.onSettingsTap,
    super.key,
  });

  final String dateLabel;
  final String greeting;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: context.appColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateLabel,
                  style: AppTextStyles.kicker.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                Text(
                  greeting,
                  style: AppTextStyles.screenTitle.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onSettingsTap != null)
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: onSettingsTap,
            ),
          const ThemeToggleButton(),
        ],
      ),
    );
  }
}
