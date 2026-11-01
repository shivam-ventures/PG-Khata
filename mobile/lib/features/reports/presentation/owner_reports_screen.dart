import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/semantic_tone.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/stat_card.dart';
import '../application/reports_providers.dart';
import '../domain/report_data.dart';

/// The Owner's portfolio analytics screen. Mirrors `Reports.dc.html`.
/// Reached from Owner's More menu or Dashboard quick action — not a
/// bottom-nav tab, so this provides its own [AppScaffold].
class OwnerReportsScreen extends ConsumerWidget {
  const OwnerReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reportsAsync = ref.watch(reportsProvider);

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.ownerReports,
                        style: AppTextStyles.screenTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        l10n.reportsSubtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.appColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: reportsAsync,
              onRetry: () => ref.invalidate(reportsProvider),
              loading: (context) => const _ReportsSkeleton(),
              data: (context, data) => _ReportsBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({required this.data});

  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        // A fixed childAspectRatio here (as the Owner Dashboard's stat grid
        // used to) gets outgrown by real, locale/font-dependent stat text —
        // StatCard already sizes itself to its own content, so plain Rows
        // let that work instead of re-guessing a magic ratio.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.currency_rupee,
                label: l10n.reportsStatTotalRevenue,
                value: CurrencyFormatter.rupees(data.totalRevenue),
                sub: l10n.reportsStatTotalRevenueSub(
                  CurrencyFormatter.rupees(data.totalExpected),
                ),
                tone: SemanticTone.success,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: StatCard(
                icon: Icons.home_outlined,
                label: l10n.reportsStatAvgOccupancy,
                value: '${data.avgOccupancyPercent}%',
                sub: l10n.reportsStatAvgOccupancySub(data.propertyComparison.length),
                tone: SemanticTone.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.calendar_month_outlined,
                label: l10n.reportsStatAvgDaysLate,
                value: data.avgDaysLate.toStringAsFixed(1),
                sub: l10n.reportsStatAvgDaysLateSub,
                tone: SemanticTone.info,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: StatCard(
                icon: Icons.check_circle_outline,
                label: l10n.reportsStatComplaintResolution,
                value: '${data.complaintResolutionPercent}%',
                sub: l10n.reportsStatComplaintResolutionSub,
                tone: SemanticTone.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space4),
        _Section(
          title: l10n.reportsRevenueByPg,
          child: _RevenueBars(bars: data.revenueByProperty),
        ),
        const SizedBox(height: AppSpacing.space4),
        _Section(
          title: l10n.reportsOccupancyTrend,
          child: _OccupancyChart(points: data.occupancyTrend),
        ),
        const SizedBox(height: AppSpacing.space4),
        Text(
          l10n.reportsPgComparison,
          style: AppTextStyles.sectionHeading.copyWith(
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        for (final row in data.propertyComparison)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: _ComparisonRow(row: row),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space4),
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
          Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.space3),
          child,
        ],
      ),
    );
  }
}

class _RevenueBars extends StatelessWidget {
  const _RevenueBars({required this.bars});

  final List<RevenueBar> bars;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (bars.isEmpty) {
      return EmptyState(
        icon: Icons.bar_chart_outlined,
        title: l10n.ownerNoPgsTitle,
        message: l10n.reportsEmptyMessage,
      );
    }
    final maxAmount = bars
        .map((b) => b.amount)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final bar in bars)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    bar.propertyName,
                    style: AppTextStyles.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          FractionallySizedBox(
                            widthFactor: maxAmount == 0
                                ? 0
                                : bar.amount / maxAmount,
                            child: Container(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                SizedBox(
                  width: 56,
                  child: Text(
                    CurrencyFormatter.rupees(bar.amount),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
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

class _OccupancyChart extends StatelessWidget {
  const _OccupancyChart({required this.points});

  final List<OccupancyPoint> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.appColors.divider),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${point.percent}%',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // A single Border can't mix per-side colors with a
                    // borderRadius (Flutter asserts on that combination) —
                    // so the accent cap is a separate strip stacked on top
                    // of a plain rounded bar instead. See TenantHomeScreen's
                    // `_RentCard` for the same pattern.
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            height: point.percent / 100 * 110,
                            color: context.appColors.accent100,
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.monthLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 10,
                        color: context.appColors.textMuted,
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

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.row});

  final PropertyComparisonRow row;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(row.propertyName, style: AppTextStyles.rowTitle),
              Text(
                CurrencyFormatter.rupees(row.revenue),
                style: AppTextStyles.rowTitle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).reportsComparisonLine(
              row.occupancyLabel,
              row.openComplaints,
              row.managerName,
            ),
            style: AppTextStyles.bodySmall.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 160),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 120),
        SizedBox(height: AppSpacing.space3),
        SkeletonBox(width: double.infinity, height: 160),
      ],
    );
  }
}
