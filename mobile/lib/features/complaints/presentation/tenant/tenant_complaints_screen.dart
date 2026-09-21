import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/cta_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/semantic_tone.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../tenants/application/tenants_providers.dart';
import '../../../tenants/domain/tenant_record.dart';
import '../../application/complaints_providers.dart';
import '../../domain/complaint.dart';
import '../../domain/complaint_status.dart';
import 'widgets/report_issue_dialog.dart';

/// The Tenant's own complaints screen. Mirrors `Tenant Complaints.dc.html`.
/// Rendered inside [RoleShell]: page content only. Reads the *signed-in*
/// tenant's own record via [currentTenantRecordProvider] — see that
/// provider's doc comment for why this matters.
class TenantComplaintsScreen extends ConsumerWidget {
  const TenantComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(currentTenantRecordProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space4,
            AppSpacing.space4,
            AppSpacing.space4,
            0,
          ),
          child: Text(
            'Complaints',
            style: AppTextStyles.screenTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: AsyncValueView(
            value: tenantAsync,
            onRetry: () => ref.invalidate(currentTenantRecordProvider),
            loading: (context) => const _ComplaintsSkeleton(),
            data: (context, tenant) => tenant == null
                ? const EmptyState(
                    icon: Icons.home_work_outlined,
                    title: 'No room assigned yet',
                    message:
                        "Once a manager assigns you a bed, you'll be able "
                        "to report issues here.",
                  )
                : _TenantComplaintsForTenant(tenant: tenant),
          ),
        ),
      ],
    );
  }
}

class _TenantComplaintsForTenant extends ConsumerWidget {
  const _TenantComplaintsForTenant({required this.tenant});

  final TenantRecord tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(tenantComplaintsProvider(tenant.id));
    return AsyncValueView(
      value: complaintsAsync,
      onRetry: () => ref.invalidate(tenantComplaintsProvider(tenant.id)),
      loading: (context) => const _ComplaintsSkeleton(),
      data: (context, complaints) =>
          _TenantComplaintsBody(complaints: complaints, tenant: tenant),
    );
  }
}

class _TenantComplaintsBody extends ConsumerWidget {
  const _TenantComplaintsBody({required this.complaints, required this.tenant});

  final List<Complaint> complaints;
  final TenantRecord tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        CtaCard(
          icon: Icons.add,
          title: 'Report an issue',
          subtitle: 'Plumbing, electrical, wifi & more',
          onTap: () => showReportIssueDialog(
            context,
            propertyId: tenant.propertyId,
            propertyName: tenant.propertyName,
            room: tenant.roomBed,
            tenantId: tenant.id,
            tenantName: tenant.name,
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        if (complaints.isEmpty)
          const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'No complaints reported',
            message: "You're all clear.",
          )
        else
          for (final complaint in complaints)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: _ComplaintRow(complaint: complaint),
            ),
      ],
    );
  }
}

class _ComplaintRow extends ConsumerWidget {
  const _ComplaintRow({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eff = complaint.effectiveStatus;
    final ageVerb = switch (eff) {
      ComplaintStatus.resolved => 'Resolved',
      ComplaintStatus.reopened => 'Reopened',
      _ => 'Reported',
    };
    final subtext = switch (eff) {
      ComplaintStatus.delegated =>
        'Being handled by ${complaint.delegatedTo} · '
            'auto-closes in ${complaint.autoResolveDaysLeft}d',
      ComplaintStatus.resolved when complaint.status == ComplaintStatus.delegated =>
        'Closed automatically',
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: context.appColors.divider),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(complaint.title, style: AppTextStyles.rowTitle),
                Text(
                  '${complaint.category.label} · $ageVerb '
                  '${RelativeTimeFormatter.ago(complaint.reportedAt)} · '
                  'prefers ${complaint.timePreference.label}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusChip(label: eff.label, tone: eff.tone),
              if (subtext != null) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: 120,
                  child: Text(
                    subtext,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ),
              ],
              if (complaint.canReopen) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => reopenComplaint(ref, complaint.id),
                  child: Text(
                    'Not fixed yet?',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
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
        SkeletonBox(width: double.infinity, height: 60),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 70),
        SizedBox(height: AppSpacing.space2),
        SkeletonBox(width: double.infinity, height: 70),
      ],
    );
  }
}
