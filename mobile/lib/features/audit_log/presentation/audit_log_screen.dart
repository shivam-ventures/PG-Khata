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
import '../application/audit_log_providers.dart';
import '../domain/audit_log_entry.dart';

/// Owner-only, portfolio-wide history of every meaningful mutation the
/// payment/complaint/tenancy RPCs recorded — read-only, never editable, per
/// `audit_log`'s own "never deleted" schema comment. Reached from Owner More.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _entityFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auditLogAsync = ref.watch(auditLogProvider);

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
                        l10n.auditLogTitle,
                        style: AppTextStyles.screenTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        l10n.auditLogSubtitle,
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
              value: auditLogAsync,
              onRetry: () => ref.invalidate(auditLogProvider),
              loading: (context) => const _AuditLogSkeleton(),
              data: (context, entries) {
                final scoped = _entityFilter == 'all'
                    ? entries
                    : entries
                          .where((e) => e.entityType == _entityFilter)
                          .toList();
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _entityFilter,
                      decoration: InputDecoration(labelText: l10n.auditLogTypeLabel),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(l10n.auditLogFilterAll),
                        ),
                        DropdownMenuItem(
                          value: 'payment',
                          child: Text(l10n.ownerPayments),
                        ),
                        DropdownMenuItem(
                          value: 'complaint',
                          child: Text(l10n.ownerComplaintsAction),
                        ),
                        DropdownMenuItem(
                          value: 'tenancy',
                          child: Text(l10n.auditLogFilterTenancies),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _entityFilter = value ?? 'all'),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    if (scoped.isEmpty)
                      EmptyState(
                        icon: Icons.history,
                        title: l10n.auditLogEmptyTitle,
                        message: l10n.auditLogEmptyMessage,
                      )
                    else
                      for (final entry in scoped)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.space2,
                          ),
                          child: _AuditLogCard(entry: entry),
                        ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.entry});

  final AuditLogEntry entry;

  IconData get _icon => switch (entry.entityType) {
    'payment' => Icons.payments_outlined,
    'complaint' => Icons.report_problem_outlined,
    'tenancy' => Icons.home_outlined,
    _ => Icons.history,
  };

  String get _actionLabel {
    final withoutPrefix = entry.action.contains('.')
        ? entry.action.substring(entry.action.indexOf('.') + 1)
        : entry.action;
    final words = withoutPrefix.replaceAll('_', ' ').trim();
    if (words.isEmpty) return entry.action;
    return '${entry.entityType[0].toUpperCase()}${entry.entityType.substring(1)} $words';
  }

  String? get _metadataLine {
    if (entry.metadata.isEmpty) return null;
    final parts = <String>[];
    for (final key in entry.metadata.keys) {
      final value = entry.metadata[key];
      if (value == null || value.toString().isEmpty) continue;
      parts.add('${key.replaceAll('_', ' ')}: $value');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metadataLine = _metadataLine;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.appColors.accent100,
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(_icon, size: 18, color: context.appColors.accent700),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_actionLabel, style: AppTextStyles.rowTitle),
                Text(
                  '${entry.actorName ?? l10n.auditLogSystemActor} · '
                  '${RelativeTimeFormatter.agoFor(l10n, entry.createdAt)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                if (metadataLine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      metadataLine,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11.5,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditLogSkeleton extends StatelessWidget {
  const _AuditLogSkeleton();

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
