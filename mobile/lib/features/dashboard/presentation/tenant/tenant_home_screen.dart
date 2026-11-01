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
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_label_formatter.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/list_row_card.dart';
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
      data: (context, data) {
        final l10n = AppLocalizations.of(context);
        return data == null
            ? EmptyState(
                icon: Icons.home_work_outlined,
                title: l10n.tenantNoRoomTitle,
                message: l10n.tenantNoRoomMessage,
              )
            : _TenantHomeContent(data: data);
      },
    );
  }
}

class _TenantHomeContent extends StatelessWidget {
  const _TenantHomeContent({required this.data});

  final TenantHomeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.tenantHello(data.firstName),
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
                  title: l10n.tenantConfirmCashTitle,
                  message: l10n.tenantConfirmCashMessage(
                    CurrencyFormatter.rupees(data.pendingCashAmount!),
                  ),
                  onTap: () => context.go(AppRoute.tenantPayments),
                ),
              if (data.hasPendingCashConfirmation)
                const SizedBox(height: AppSpacing.space4),
              if (data.hasAnnouncement)
                _InfoBanner(
                  icon: Icons.campaign_outlined,
                  title: l10n.tenantAnnouncementTitle,
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
                      label: l10n.tenantReportIssue,
                      tone: SemanticTone.warning,
                      onTap: () => context.go(AppRoute.tenantComplaints),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.receipt_long_outlined,
                      label: l10n.tenantRentHistory,
                      tone: SemanticTone.accent,
                      onTap: () => context.go(AppRoute.tenantPayments),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.apartment_outlined,
                      label: l10n.tenantMyPg,
                      tone: SemanticTone.info,
                      onTap: () => _showPgInfo(context, l10n, data),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.tenantLastPayment,
                    style: AppTextStyles.sectionHeading.copyWith(fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoute.tenantPayments),
                    child: Text(
                      l10n.commonSeeAll,
                      style: const TextStyle(
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
                  child: ListRowCard(
                    title: DateLabelFormatter.monthYear(payment.periodMonth),
                    subtitle:
                        '${payment.method?.labelFor(l10n) ?? '—'} · '
                        '${DateLabelFormatter.short(payment.paidDate)}',
                    trailing: StatusChip(
                      label: payment.status.labelFor(l10n),
                      tone: payment.tone,
                    ),
                  ),
                ),
              if (data.hasOpenComplaint) ...[
                const SizedBox(height: AppSpacing.space4),
                Text(
                  l10n.tenantComplaintStatus,
                  style: AppTextStyles.sectionHeading.copyWith(fontSize: 18),
                ),
                const SizedBox(height: AppSpacing.space2),
                ListRowCard(
                  title: data.openComplaintTitle!,
                  subtitle: l10n.tenantReportedTime(
                    RelativeTimeFormatter.agoFor(
                      l10n,
                      data.openComplaintReportedAt!,
                    ),
                  ),
                  trailing: StatusChip(
                    label: data.openComplaintStatus!.labelFor(l10n),
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

  void _showPgInfo(BuildContext context, AppLocalizations l10n, TenantHomeData data) {
    AppDialog.show<void>(
      context,
      title: data.pgName,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tenantPgAddress(data.pgAddress)),
          const SizedBox(height: AppSpacing.space2),
          Text(
            l10n.tenantPgManager(
              data.managerName.isEmpty
                  ? l10n.tenantYourManagerFallback
                  : data.managerName,
            ),
          ),
          if (data.managerPhone != null) ...[
            const SizedBox(height: AppSpacing.space3),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: l10n.tenantCallManager,
                    onPressed: () => launchUrl(
                      Uri(scheme: 'tel', path: data.managerPhone),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: SecondaryButton(
                    label: l10n.tenantMessageManager,
                    onPressed: () => launchUrl(
                      Uri(scheme: 'sms', path: data.managerPhone),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
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

  String _dueLabel(AppLocalizations l10n) {
    if (data.isOverdue) return l10n.tenantRentOverdue;
    final days = data.currentDueDate!.difference(DateTime.now()).inDays;
    if (days <= 0) return l10n.tenantRentDueToday;
    return l10n.tenantRentDueInDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final rentAmountLabel = CurrencyFormatter.rupees(data.rentAmount);
    return data.isRentDueSoon
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n
                    .tenantRoomAndDue(data.room, _dueLabel(l10n))
                    .toUpperCase(),
                style: AppTextStyles.kickerUppercase.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                rentAmountLabel,
                style: AppTextStyles.displayAmount.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              PrimaryButton(
                label: l10n.tenantPayRent,
                onPressed: () => context.go(AppRoute.tenantPayments),
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
                      l10n.tenantAllPaidUp,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.tenantNextRentDue(
                        data.room,
                        rentAmountLabel,
                        data.currentDueDate == null
                            ? ''
                            : DateLabelFormatter.short(
                                DateTime(
                                  data.currentDueDate!.year,
                                  data.currentDueDate!.month + 1,
                                  data.currentDueDate!.day,
                                ),
                              ),
                      ),
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
