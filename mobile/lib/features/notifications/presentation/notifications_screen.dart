import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/relative_time_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../application/notifications_providers.dart';
import '../domain/app_notification.dart';

/// One shared inbox screen for all three roles — RLS already scopes
/// `notifications` to `recipient_user_id = auth.uid()`, so there's nothing
/// role-specific to branch on here, unlike most other "More" destinations.
/// Reached from each role's More/Profile menu.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notificationsAsync = ref.watch(notificationsProvider);
    final hasUnread =
        notificationsAsync.value?.any((n) => n.isUnread) ?? false;

    return AppScaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.space4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: context.appColors.divider),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                ),
                Expanded(
                  child: Text(
                    l10n.accountNotifications,
                    style: AppTextStyles.screenTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (hasUnread)
                  TextButton(
                    onPressed: () => markAllNotificationsRead(ref),
                    child: Text(l10n.notificationsMarkAllRead),
                  ),
                IconButton(
                  onPressed: () => ref.invalidate(notificationsProvider),
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.commonRefresh,
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: notificationsAsync,
              onRetry: () => ref.invalidate(notificationsProvider),
              loading: (context) => const _NotificationsSkeleton(),
              data: (context, notifications) => notifications.isEmpty
                  ? EmptyState(
                      icon: Icons.notifications_none,
                      title: l10n.notificationsEmptyTitle,
                      message: l10n.notificationsEmptyMessage,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.space4),
                      children: [
                        for (final notification in notifications)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.space2,
                            ),
                            child: _NotificationCard(
                              notification: notification,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  IconData get _icon => switch (notification.kind) {
    final k when k.startsWith('payment') => Icons.payments_outlined,
    final k when k.startsWith('dispute') => Icons.gavel_outlined,
    final k when k.startsWith('complaint') => Icons.report_problem_outlined,
    final k when k.startsWith('tenancy') => Icons.home_outlined,
    _ => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUnread = notification.isUnread;

    return InkWell(
      onTap: isUnread
          ? () => markNotificationRead(ref, notification.id)
          : null,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space3,
        ),
        decoration: BoxDecoration(
          color: isUnread
              ? context.appColors.accent100.withValues(alpha: 0.35)
              : theme.colorScheme.surface,
          border: Border.all(color: context.appColors.divider),
          borderRadius: AppRadius.mdAll,
          boxShadow: AppShadows.of(theme.brightness),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.appColors.accent100,
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(
                _icon,
                size: 18,
                color: context.appColors.accent700,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: AppTextStyles.rowTitle.copyWith(
                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if (notification.body != null &&
                      notification.body!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        notification.body!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      RelativeTimeFormatter.agoFor(
                        AppLocalizations.of(context),
                        notification.createdAt,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11.5,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(left: AppSpacing.space2, top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.appColors.accent700,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 70),
        SizedBox(height: AppSpacing.space2),
        SkeletonBox(width: double.infinity, height: 70),
        SizedBox(height: AppSpacing.space2),
        SkeletonBox(width: double.infinity, height: 70),
      ],
    );
  }
}
