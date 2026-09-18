import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_label_formatter.dart';
import '../../../../core/utils/greeting_formatter.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/dashboard_header.dart';
import '../../../../shared/widgets/not_built_yet.dart';
import '../../../../shared/widgets/quick_action_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/semantic_tone.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../application/dashboard_providers.dart';
import '../../domain/manager_today_data.dart';

/// The Manager's home screen — day-to-day operations at one PG. Mirrors
/// `Manager Today.dc.html`. Rendered inside [RoleShell]: page content only.
class ManagerTodayScreen extends ConsumerWidget {
  const ManagerTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(managerTodayProvider);
    return AsyncValueView(
      value: today,
      onRetry: () => ref.invalidate(managerTodayProvider),
      loading: (context) => const _ManagerTodaySkeleton(),
      data: (context, data) => _ManagerTodayContent(data: data),
    );
  }
}

class _ManagerTodayContent extends ConsumerWidget {
  const _ManagerTodayContent({required this.data});

  final ManagerTodayData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      children: [
        DashboardHeader(
          dateLabel: DateLabelFormatter.today(),
          greeting: GreetingFormatter.greeting(data.managerFirstName),
          onSettingsTap: () => context.go(AppRoute.managerMore),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space2,
          ),
          decoration: BoxDecoration(
            color: context.appColors.surfaceAlt,
            border: Border(
              bottom: BorderSide(color: context.appColors.divider),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PgSwitcher(options: data.pgOptions, currentId: data.currentPgId),
              Text(
                'Managing this PG',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.space4),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Occupancy',
                      value: data.occupancyLabel,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: _MiniStat(
                      label: 'Pending today',
                      value: data.pendingLabel,
                      valueColor: context.appColors.warning700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: _MiniStat(
                      label: 'Complaints',
                      value: data.complaintsCountLabel,
                      valueColor: context.appColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space6),
              Row(
                children: [
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.payments_outlined,
                      label: 'Collect Rent',
                      tone: SemanticTone.success,
                      onTap: () => context.go(AppRoute.managerPayments),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.person_add_alt_outlined,
                      label: 'Add Tenant',
                      tone: SemanticTone.accent,
                      onTap: () =>
                          context.push('${AppRoute.managerTenants}?add=1'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.grid_view_outlined,
                      label: 'View Rooms',
                      tone: SemanticTone.info,
                      onTap: () => context.go(AppRoute.managerRooms),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.report_problem_outlined,
                      label: 'Complaints',
                      tone: SemanticTone.warning,
                      onTap: () => notifyNotBuiltYet(
                        context,
                        feature: 'Complaints',
                        phase: 'Phase 5',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space6),
              if (data.hasTasks) ...[
                if (data.rentTasks.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Rent to collect',
                    actionLabel: 'See all',
                    onAction: () => context.go(AppRoute.managerPayments),
                  ),
                  for (final task in data.rentTasks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                      child: _TaskCard(
                        title: task.tenantName,
                        subtitle: task.room,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              task.amountLabel,
                              style: AppTextStyles.rowTitle.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space2),
                            ElevatedButton(
                              onPressed: () =>
                                  context.go(AppRoute.managerPayments),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: const Text('Collect'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.space6),
                ],
                if (data.complaintTasks.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Open complaints',
                    actionLabel: 'See all',
                    onAction: () => notifyNotBuiltYet(
                      context,
                      feature: 'Complaints',
                      phase: 'Phase 5',
                    ),
                  ),
                  for (final task in data.complaintTasks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                      child: _TaskCard(
                        title: task.title,
                        subtitle: '${task.room} · ${task.age}',
                        trailing: StatusChip(
                          label: task.status,
                          tone: task.tone,
                        ),
                      ),
                    ),
                ],
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space8,
                  ),
                  child: Center(
                    child: Text(
                      'All caught up for today.',
                      style: AppTextStyles.body.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PgSwitcher extends ConsumerWidget {
  const _PgSwitcher({required this.options, required this.currentId});

  final List<PgOption> options;
  final String currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = options.firstWhere(
      (o) => o.id == currentId,
      orElse: () => options.first,
    );
    return PopupMenuButton<String>(
      initialValue: currentId,
      onSelected: (id) =>
          ref.read(managerSelectedPgIdProvider.notifier).select(id),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(value: option.id, child: Text(option.name)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: context.appColors.divider),
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.name,
              style: AppTextStyles.rowTitle.copyWith(fontSize: 13),
            ),
            const SizedBox(width: AppSpacing.space1),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: context.appColors.divider),
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadows.of(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.kicker.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.statValue.copyWith(
              fontSize: 19,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
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

class _ManagerTodaySkeleton extends StatelessWidget {
  const _ManagerTodaySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonLine(width: 160),
        SizedBox(height: AppSpacing.space2),
        SkeletonLine(width: 220, height: 22),
        SizedBox(height: AppSpacing.space6),
        SkeletonBox(width: double.infinity, height: 70),
        SizedBox(height: AppSpacing.space6),
        SkeletonBox(width: double.infinity, height: 140),
      ],
    );
  }
}
