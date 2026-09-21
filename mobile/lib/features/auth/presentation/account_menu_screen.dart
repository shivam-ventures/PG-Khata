import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../application/auth_controller.dart';

/// One entry in [AccountMenuScreen]'s optional overflow-menu section —
/// used for a role's "More" links that don't have their own bottom-nav tab
/// (Manager's Tenants/Complaints, per `Manager More.dc.html`).
class AccountMenuItem {
  const AccountMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Stands in for the full `Settings.dc.html` screen (Phase 1+ scope), but
/// surfaces the one thing Phase 0's definition of done requires from it:
/// session info and a working logout — plus, when [extraMenuItems] is
/// given, the overflow links a role's design routes through "More"
/// (Manager Tenants/Complaints) rather than its own bottom-nav tab.
///
/// Rendered inside a role's `RoleShell` — see `PlaceholderScreen`'s doc
/// comment for why this returns page content rather than its own `Scaffold`.
class AccountMenuScreen extends ConsumerWidget {
  const AccountMenuScreen({this.extraMenuItems = const [], super.key});

  final List<AccountMenuItem> extraMenuItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account',
            style: AppTextStyles.sectionHeading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: AppSpacing.space6),
          if (extraMenuItems.isNotEmpty) ...[
            for (final item in extraMenuItems)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.icon),
                title: Text(item.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: item.onTap,
              ),
            const SizedBox(height: AppSpacing.space2),
            Divider(color: context.appColors.divider),
            const SizedBox(height: AppSpacing.space4),
          ],
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
