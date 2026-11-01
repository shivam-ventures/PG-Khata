import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/semantic_tone.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../properties/application/properties_providers.dart';
import '../../../properties/domain/property.dart';
import '../../application/complaints_providers.dart';
import '../../domain/complaint.dart';
import '../../domain/complaint_severity.dart';
import '../../domain/complaint_status.dart';
import '../manager/widgets/complaint_action_dialog.dart';

/// The Owner's portfolio-wide complaint list — the same ledger Manager
/// Complaints reads per-property, filterable down to one PG. `report_complaint`'s
/// authorization (`is_staff_for_property`) already covers an Owner, so
/// delegate/resolve/reopen work identically here via the same dialog
/// Manager Complaints uses; this screen was the one gap where an Owner
/// could only see an aggregate count on the dashboard, never the list
/// itself. Reached from Owner More — not a bottom-nav tab, so this
/// provides its own [AppScaffold].
class OwnerComplaintsScreen extends ConsumerStatefulWidget {
  const OwnerComplaintsScreen({super.key});

  @override
  ConsumerState<OwnerComplaintsScreen> createState() =>
      _OwnerComplaintsScreenState();
}

class _OwnerComplaintsScreenState extends ConsumerState<OwnerComplaintsScreen> {
  String _propertyFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final complaintsAsync = ref.watch(portfolioComplaintsProvider);
    final propertiesAsync = ref.watch(propertiesProvider);

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
                  l10n.complaintsTitle,
                  style: AppTextStyles.screenTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: complaintsAsync,
              onRetry: () => ref.invalidate(portfolioComplaintsProvider),
              loading: (context) => const _ComplaintsSkeleton(),
              data: (context, complaints) => _OwnerComplaintsBody(
                complaints: complaints,
                propertiesAsync: propertiesAsync,
                propertyFilter: _propertyFilter,
                onPropertyFilterChanged: (value) =>
                    setState(() => _propertyFilter = value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerComplaintsBody extends StatelessWidget {
  const _OwnerComplaintsBody({
    required this.complaints,
    required this.propertiesAsync,
    required this.propertyFilter,
    required this.onPropertyFilterChanged,
  });

  final List<Complaint> complaints;
  final AsyncValue<List<Property>> propertiesAsync;
  final String propertyFilter;
  final ValueChanged<String> onPropertyFilterChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scoped = propertyFilter == 'all'
        ? complaints
        : complaints.where((c) => c.propertyId == propertyFilter).toList();
    final open = scoped
        .where((c) => c.effectiveStatus != ComplaintStatus.resolved)
        .length;
    final highPriority = scoped
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
                label: l10n.complaintsStatOpen,
                value: '$open',
                tone: SemanticTone.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: StatCard(
                icon: Icons.priority_high,
                label: l10n.complaintsStatHighPriority,
                value: '$highPriority',
                tone: SemanticTone.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space4),
        propertiesAsync.when(
          data: (properties) => DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: propertyFilter,
            decoration: InputDecoration(labelText: l10n.commonPg),
            items: [
              DropdownMenuItem(value: 'all', child: Text(l10n.commonAllPgs)),
              for (final property in properties)
                DropdownMenuItem(
                  value: property.id,
                  child: Text(property.name),
                ),
            ],
            onChanged: (value) => onPropertyFilterChanged(value ?? 'all'),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.space4),
        if (scoped.isEmpty)
          EmptyState(
            icon: Icons.celebration_outlined,
            title: l10n.ownerComplaintsEmptyTitle,
            message: l10n.complaintsNothingOpenMessage,
          )
        else
          for (final complaint in scoped)
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final eff = complaint.effectiveStatus;
    final isHighPriority =
        complaint.severity == ComplaintSeverity.high &&
        eff != ComplaintStatus.resolved;
    final subtext = switch (eff) {
      ComplaintStatus.delegated => l10n.complaintDelegatedArrowSub(
        complaint.delegatedTo ?? '',
        complaint.autoResolveDaysLeft,
      ),
      ComplaintStatus.resolved when complaint.status == ComplaintStatus.delegated =>
        l10n.complaintAutoResolvedNoComplaint,
      ComplaintStatus.resolved => l10n.complaintMarkedResolved,
      ComplaintStatus.reopened => l10n.complaintTenantSaysNotFixed,
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
                    l10n.complaintPropertyRoomTenantOpen(
                      complaint.propertyName,
                      complaint.room,
                      complaint.tenantName,
                      RelativeTimeFormatter.openFor(l10n, complaint.reportedAt),
                    ),
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
            StatusChip(label: eff.labelFor(l10n), tone: eff.tone),
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
