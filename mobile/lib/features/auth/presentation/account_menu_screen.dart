import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_route.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../notifications/application/notifications_providers.dart';
import '../application/auth_controller.dart';
import '../domain/app_user.dart';
import '../domain/user_role.dart';

/// One entry in [AccountMenuScreen]'s optional overflow-menu section —
/// used for a role's "More" links that don't have their own bottom-nav tab
/// (Manager's Tenants/Complaints, per `Manager More.dc.html`).
class AccountMenuItem {
  const AccountMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// A small count chip after the label (e.g. unread notifications) — 0
  /// renders nothing.
  final int badgeCount;
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
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).value;
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);
    final notificationsPath = switch (user?.role) {
      UserRole.owner => AppRoute.ownerNotifications,
      UserRole.manager => AppRoute.managerNotifications,
      UserRole.tenant || null => AppRoute.tenantNotifications,
    };
    final items = [
      AccountMenuItem(
        icon: Icons.notifications_none,
        label: l10n.accountNotifications,
        badgeCount: unreadNotifications,
        onTap: () => context.push(notificationsPath),
      ),
      ...extraMenuItems,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.accountTitle,
            style: AppTextStyles.sectionHeading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: AppSpacing.space6),
          if (items.isNotEmpty) ...[
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.icon),
                title: Text(item.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.badgeCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.appColors.danger,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${item.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                    ],
                    const Icon(Icons.chevron_right),
                  ],
                ),
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
              '${user.role.labelFor(l10n)} · +91 ${user.phone}',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.space6),
          ],
          if (user != null) ...[
            Text(
              l10n.settingsTitle,
              style: AppTextStyles.sectionHeading.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.space3),
            _SettingsSection(user: user),
            const SizedBox(height: AppSpacing.space6),
          ],
          SecondaryButton(
            label: l10n.commonLogOut,
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

/// Language + notification preferences — the real `Settings.dc.html`,
/// finally, replacing the "coming in a later phase" placeholder this
/// screen showed since Phase 0. Rent reminders aren't a toggle here: the
/// approved design made that one mandatory/always-on, so there's nothing
/// to store or switch for it.
class _SettingsSection extends ConsumerStatefulWidget {
  const _SettingsSection({required this.user});

  final AppUser user;

  @override
  ConsumerState<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends ConsumerState<_SettingsSection> {
  bool _isSaving = false;

  Future<void> _save({
    String? preferredLanguage,
    bool? notifyComplaints,
    bool? notifyAnnouncements,
  }) async {
    setState(() => _isSaving = true);
    final failure = await ref
        .read(authControllerProvider.notifier)
        .updatePreferences(
          preferredLanguage: preferredLanguage,
          notifyComplaints: notifyComplaints,
          notifyAnnouncements: notifyAnnouncements,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Opacity(
      opacity: _isSaving ? 0.6 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsLanguage,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.space1),
          DropdownButtonFormField<String>(
            initialValue: widget.user.preferredLanguage,
            items: [
              DropdownMenuItem(
                value: 'en',
                child: Text(l10n.settingsLanguageEnglish),
              ),
              DropdownMenuItem(
                value: 'te',
                child: Text(l10n.settingsLanguageTelugu),
              ),
            ],
            onChanged: _isSaving
                ? null
                : (value) {
                    if (value != null) _save(preferredLanguage: value);
                  },
          ),
          const SizedBox(height: AppSpacing.space4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsRentReminders),
            subtitle: Text(l10n.settingsAlwaysOn),
            value: true,
            onChanged: null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsComplaintUpdates),
            value: widget.user.notifyComplaints,
            onChanged: _isSaving
                ? null
                : (value) => _save(notifyComplaints: value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsAnnouncements),
            value: widget.user.notifyAnnouncements,
            onChanged: _isSaving
                ? null
                : (value) => _save(notifyAnnouncements: value),
          ),
        ],
      ),
    );
  }
}
