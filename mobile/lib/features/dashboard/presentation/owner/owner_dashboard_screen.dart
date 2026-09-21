import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_label_formatter.dart';
import '../../../../core/utils/greeting_formatter.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/dashboard_header.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/not_built_yet.dart';
import '../../../../shared/widgets/quick_action_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/semantic_tone.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../properties/presentation/widgets/import_properties_dialog.dart';
import '../../application/dashboard_providers.dart';
import '../../domain/dashboard_stat.dart';
import '../../domain/owner_dashboard_data.dart';
import 'widgets/attention_card.dart';

/// The Owner's home screen — portfolio-level oversight across properties.
/// Mirrors `Owner Dashboard.dc.html`. Rendered inside [RoleShell]: this
/// widget is page content only, not its own `Scaffold`.
class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(ownerDashboardProvider);
    return AsyncValueView(
      value: dashboard,
      onRetry: () => ref.invalidate(ownerDashboardProvider),
      loading: (context) => const _OwnerDashboardSkeleton(),
      data: (context, data) => _OwnerDashboardContent(data: data),
    );
  }
}

class _OwnerDashboardContent extends StatelessWidget {
  const _OwnerDashboardContent({required this.data});

  final OwnerDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DashboardHeader(
          dateLabel: DateLabelFormatter.today(),
          greeting: GreetingFormatter.greeting(data.ownerFirstName),
          onSettingsTap: () => context.go(AppRoute.ownerMore),
        ),
        Expanded(
          child: data.hasProperties
              ? _PopulatedBody(data: data)
              : Center(
                  child: EmptyState(
                    icon: Icons.home_work_outlined,
                    title: 'No PGs yet',
                    message: "Let's set up your first PG — add rooms and beds, then invite a manager or tenants.",
                    primaryActionLabel: 'Add PG',
                    onPrimaryAction: () => context.go(AppRoute.ownerProperties),
                    secondaryActionLabel: 'Import from Excel',
                    onSecondaryAction: () =>
                        showImportPropertiesDialog(context),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PopulatedBody extends StatelessWidget {
  const _PopulatedBody({required this.data});

  final OwnerDashboardData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        if (data.hasAttentionItems) ...[
          AttentionCard(
            items: data.attentionItems,
            onView: (destination) => switch (destination) {
              'payments' => context.push(AppRoute.ownerPayments),
              'rooms' => context.go(AppRoute.ownerProperties),
              _ => notifyNotBuiltYet(
                context,
                feature: 'Complaints',
                phase: 'a later phase',
              ),
            },
          ),
          const SizedBox(height: AppSpacing.space6),
        ],
        Row(
          children: [
            Expanded(
              child: QuickActionButton(
                icon: Icons.payments_outlined,
                label: 'Payments',
                tone: SemanticTone.success,
                onTap: () => context.push(AppRoute.ownerPayments),
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
                  phase: 'a later phase',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: QuickActionButton(
                icon: Icons.bar_chart_outlined,
                label: 'Reports',
                tone: SemanticTone.info,
                onTap: () => context.push(AppRoute.ownerReports),
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: QuickActionButton(
                icon: Icons.apartment_outlined,
                label: 'PGs',
                tone: SemanticTone.accent,
                onTap: () => context.go(AppRoute.ownerProperties),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space6),
        // A fixed childAspectRatio here kept getting outgrown by real
        // (longer, locale/font-dependent) stat text — StatCard already
        // sizes itself to its own content, so pairing plain Rows lets that
        // work instead of re-guessing a magic ratio every time it breaks.
        for (var i = 0; i < data.stats.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < data.stats.length ? AppSpacing.space3 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _StatCardFor(data.stats[i])),
                const SizedBox(width: AppSpacing.space3),
                if (i + 1 < data.stats.length)
                  Expanded(child: _StatCardFor(data.stats[i + 1]))
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.space6),
        SectionHeader(
          title: 'PGs',
          actionLabel: 'View all',
          onAction: () => context.go(AppRoute.ownerProperties),
        ),
        for (final property in data.properties)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: _PropertyCard(
              property: property,
              onTap: () => context.go(AppRoute.ownerProperties),
            ),
          ),
      ],
    );
  }
}

class _StatCardFor extends StatelessWidget {
  const _StatCardFor(this.stat);

  final DashboardStat stat;

  @override
  Widget build(BuildContext context) {
    return StatCard(
      icon: stat.icon,
      label: stat.label,
      value: stat.value,
      sub: stat.sub,
      tone: stat.tone,
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property, required this.onTap});

  final PropertyOverview property;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: context.appColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  property.name,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                StatusChip(
                  label: property.complaintsLabel,
                  tone: property.complaintsTone,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Occupancy: ${property.occupancyLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                Text(
                  property.rentLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
            Text(
              'Manager: ${property.managerName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerDashboardSkeleton extends StatelessWidget {
  const _OwnerDashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonLine(width: 160),
        SizedBox(height: AppSpacing.space2),
        SkeletonLine(width: 220, height: 22),
        SizedBox(height: AppSpacing.space6),
        SkeletonBox(width: double.infinity, height: 90),
        SizedBox(height: AppSpacing.space6),
        SkeletonBox(width: double.infinity, height: 160),
      ],
    );
  }
}
