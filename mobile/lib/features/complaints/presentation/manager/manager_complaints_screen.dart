import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/pg_context_bar.dart';
import '../../../../shared/widgets/semantic_tone.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../dashboard/application/dashboard_providers.dart';
import '../../application/complaints_providers.dart';
import '../../domain/complaint.dart';
import '../../domain/complaint_severity.dart';
import '../../domain/complaint_status.dart';
import 'widgets/complaint_action_dialog.dart';

/// The Manager's complaint list for their current PG. Mirrors `Manager
/// Complaints.dc.html`. Reached from Manager Today or More — not a
/// bottom-nav tab, so this provides its own [AppScaffold].
class ManagerComplaintsScreen extends ConsumerWidget {
  const ManagerComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyId = ref.watch(managerSelectedPgIdProvider);
    final complaintsAsync = ref.watch(managerComplaintsProvider(propertyId));

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
                Text(
                  'Complaints',
                  style: AppTextStyles.screenTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const PgContextBar(),
          Expanded(
            child: AsyncValueView(
              value: complaintsAsync,
              onRetry: () =>
                  ref.invalidate(managerComplaintsProvider(propertyId)),
              loading: (context) => const _ComplaintsSkeleton(),
              data: (context, complaints) =>
                  _ManagerComplaintsBody(complaints: complaints),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerComplaintsBody extends StatelessWidget {
  const _ManagerComplaintsBody({required this.complaints});

  final List<Complaint> complaints;

  @override
  Widget build(BuildContext context) {
    final open = complaints
        .where((c) => c.effectiveStatus != ComplaintStatus.resolved)
        .length;
    final highPriority = complaints
        .where(
          (c) =>
              c.severity == ComplaintSeverity.high &&
              c.effectiveStatus != ComplaintStatus.resolved,
        )
        .length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.report_problem_outlined,
                label: 'Open',
                value: '$open',
                tone: SemanticTone.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: StatCard(
                icon: Icons.priority_high,
                label: 'High priority',
                value: '$highPriority',
                tone: SemanticTone.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space4),
        if (complaints.isEmpty)
          const EmptyState(
            icon: Icons.celebration_outlined,
            title: 'No complaints for this PG',
            message: 'Nothing open right now.',
          )
        else
          for (final complaint in complaints)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: _ComplaintCard(complaint: complaint),
            ),
      ],
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eff = complaint.effectiveStatus;
    final isHighPriority =
        complaint.severity == ComplaintSeverity.high &&
        eff != ComplaintStatus.resolved;
    final subtext = switch (eff) {
      ComplaintStatus.delegated =>
        '→ ${complaint.delegatedTo} · auto-resolves in '
            '${complaint.autoResolveDaysLeft}d',
      ComplaintStatus.resolved when complaint.status == ComplaintStatus.delegated =>
        'Auto-resolved — no complaint from tenant',
      ComplaintStatus.resolved => 'Marked resolved by you',
      ComplaintStatus.reopened => "Tenant says it's still not fixed",
      _ => null,
    };

    return InkWell(
      onTap: () => showComplaintActionDialog(context, complaint: complaint),
      borderRadius: AppRadius.mdAll,
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: complaint.category.tone.background(context),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(
                    complaint.category.icon,
                    size: 18,
                    color: complaint.category.tone.foreground(context),
                  ),
                ),
                if (isHighPriority)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.appColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      // Not color alone — a colorblind manager scanning the
                      // list still needs a shape to tell "high priority"
                      // apart from a plain decorative dot.
                      child: const Icon(
                        Icons.priority_high,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(complaint.title, style: AppTextStyles.rowTitle),
                  Text(
                    '${complaint.room} · ${complaint.tenantName} · '
                    '${RelativeTimeFormatter.open(complaint.reportedAt)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  if (subtext != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        subtext,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11.5,
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            StatusChip(label: eff.label, tone: eff.tone),
          ],
        ),
      ),
    );
  }
}

class _ComplaintsSkeleton extends StatelessWidget {
  const _ComplaintsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 90),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 70),
        SizedBox(height: AppSpacing.space2),
        SkeletonBox(width: double.infinity, height: 70),
      ],
    );
  }
}
