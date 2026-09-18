import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/not_built_yet.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/quick_action_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../shared/widgets/semantic_tone.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/theme_toggle_button.dart';
import '../../application/dashboard_providers.dart';
import '../../domain/tenant_home_data.dart';

/// The Tenant's home screen — self-service for the resident. Mirrors
/// `Tenant Home.dc.html`. Rendered inside [RoleShell]: page content only.
class TenantHomeScreen extends ConsumerWidget {
  const TenantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(tenantHomeProvider);
    return AsyncValueView(
      value: home,
      onRetry: () => ref.invalidate(tenantHomeProvider),
      loading: (context) => const _TenantHomeSkeleton(),
      data: (context, data) => _TenantHomeContent(data: data),
    );
  }
}

class _TenantHomeContent extends StatelessWidget {
  const _TenantHomeContent({required this.data});

  final TenantHomeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Hello, ${data.firstName} 👋',
                  style: AppTextStyles.screenTitle.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontSize: 19,
                  ),
                ),
              ),
              const ThemeToggleButton(),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space4,
              0,
              AppSpacing.space4,
              AppSpacing.space4,
            ),
            children: [
              if (data.hasPendingCashConfirmation)
                _InfoBanner(
                  icon: Icons.currency_rupee,
                  title: 'Confirm your cash payment',
                  message:
                      'Manager recorded ${data.pendingCashAmountLabel} cash — tap to confirm or dispute.',
                  onTap: () => context.go(AppRoute.tenantPayments),
                ),
              if (data.hasPendingCashConfirmation)
                const SizedBox(height: AppSpacing.space4),
              if (data.hasAnnouncement)
                _InfoBanner(
                  icon: Icons.campaign_outlined,
                  title: 'Announcement',
                  message: data.announcement!,
                ),
              if (data.hasAnnouncement)
                const SizedBox(height: AppSpacing.space4),
              _RentCard(data: data),
              const SizedBox(height: AppSpacing.space4),
              Row(
                children: [
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.report_problem_outlined,
                      label: 'Report Issue',
                      tone: SemanticTone.warning,
                      onTap: () => context.go(AppRoute.tenantComplaints),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.receipt_long_outlined,
                      label: 'Rent History',
                      tone: SemanticTone.accent,
                      onTap: () => context.go(AppRoute.tenantPayments),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.apartment_outlined,
                      label: 'My PG',
                      tone: SemanticTone.info,
                      onTap: () => _showPgInfo(context, data),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last payment',
                    style: AppTextStyles.sectionHeading.copyWith(fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoute.tenantPayments),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space2),
              for (final payment in data.recentPayments)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                  child: _ListRow(
                    title: payment.periodLabel,
                    subtitle: '${payment.method} · ${payment.date}',
                    trailing: StatusChip(
                      label: payment.status,
                      tone: payment.tone,
                    ),
                  ),
                ),
              if (data.hasOpenComplaint) ...[
                const SizedBox(height: AppSpacing.space4),
                Text(
                  'Complaint status',
                  style: AppTextStyles.sectionHeading.copyWith(fontSize: 18),
                ),
                const SizedBox(height: AppSpacing.space2),
                _ListRow(
                  title: data.openComplaintTitle!,
                  subtitle: data.openComplaintAge!,
                  trailing: StatusChip(
                    label: data.openComplaintStatus!,
                    tone: SemanticTone.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showPgInfo(BuildContext context, TenantHomeData data) {
    AppDialog.show<void>(
      context,
      title: data.pgName,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Address: ${data.pgAddress}'),
          const SizedBox(height: AppSpacing.space2),
          Text('Manager: ${data.managerName}'),
          const SizedBox(height: AppSpacing.space3),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Call manager',
                  onPressed: () =>
                      launchUrl(Uri(scheme: 'tel', path: data.managerPhone)),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: SecondaryButton(
                  label: 'Message',
                  onPressed: () =>
                      launchUrl(Uri(scheme: 'sms', path: data.managerPhone)),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = SemanticTone.info;
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: tone.background(context),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone.foreground(context)),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.kicker.copyWith(
                    color: tone.foreground(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? content
        : InkWell(onTap: onTap, borderRadius: AppRadius.mdAll, child: content);
  }
}

class _RentCard extends StatelessWidget {
  const _RentCard({required this.data});

  final TenantHomeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = data.isRentDueSoon
        ? (data.isOverdue
              ? context.appColors.danger
              : theme.colorScheme.primary)
        : context.appColors.success;

    // A single Border can't mix per-side colors with a borderRadius (Flutter
    // asserts on that combination) — so the accent stripe is a separate
    // clipped strip inside a uniformly-bordered container instead.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.mdOf(theme.brightness),
        border: Border.all(color: context.appColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: accentColor),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space6),
            child: _RentCardBody(data: data),
          ),
        ],
      ),
    );
  }
}

class _RentCardBody extends StatelessWidget {
  const _RentCardBody({required this.data});

  final TenantHomeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return data.isRentDueSoon
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ROOM ${data.room} · ${data.dueLabel.toUpperCase()}',
                style: AppTextStyles.kickerUppercase.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                data.rentAmountLabel,
                style: AppTextStyles.displayAmount.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              PrimaryButton(
                label: 'Pay Rent',
                onPressed: () => notifyNotBuiltYet(
                  context,
                  feature: 'Online rent payment',
                  phase: 'Phase 3',
                ),
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle,
                color: context.appColors.success,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "You're all paid up",
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Room ${data.room} · Next rent of ${data.rentAmountLabel} due ${data.nextDueDateLabel}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

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
                Text(title, style: AppTextStyles.rowTitle),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _TenantHomeSkeleton extends StatelessWidget {
  const _TenantHomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonLine(width: 160, height: 22),
        SizedBox(height: AppSpacing.space6),
        SkeletonBox(width: double.infinity, height: 140),
        SizedBox(height: AppSpacing.space6),
        SkeletonBox(width: double.infinity, height: 90),
      ],
    );
  }
}
