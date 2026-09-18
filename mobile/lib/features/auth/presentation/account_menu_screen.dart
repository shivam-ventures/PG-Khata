import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../application/auth_controller.dart';

/// Stands in for the full `Settings.dc.html` screen (Phase 1+ scope), but
/// surfaces the one thing Phase 0's definition of done requires from it:
/// session info and a working logout.
///
/// Rendered inside a role's `RoleShell` — see `PlaceholderScreen`'s doc
/// comment for why this returns page content rather than its own `Scaffold`.
class AccountMenuScreen extends ConsumerWidget {
  const AccountMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account',
            style: AppTextStyles.sectionHeading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: AppSpacing.space6),
          if (user != null) ...[
            Text(user.name, style: AppTextStyles.cardTitle),
            const SizedBox(height: AppSpacing.space1),
            Text(
              '${user.role.label} · +91 ${user.phone}',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.space6),
          ],
          Text(
            'Profile, notification preferences and language are coming in a later phase.',
            style: AppTextStyles.bodySmall.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.space6),
          SecondaryButton(
            label: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
