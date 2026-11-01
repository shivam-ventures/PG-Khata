import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_text_field.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../../../shared/widgets/semantic_tone.dart';
import '../../../application/complaints_providers.dart';
import '../../../domain/complaint_category.dart';
import '../../../domain/complaint_severity.dart';
import '../../../domain/time_preference.dart';

/// Splits [items] into fixed-size groups, the last one possibly shorter.
List<List<T>> _chunk<T>(List<T> items, int size) => [
  for (var i = 0; i < items.length; i += size)
    items.sublist(i, i + size > items.length ? items.length : i + size),
];

/// The Tenant's "Report an issue" dialog from `Tenant Complaints.dc.html`.
Future<void> showReportIssueDialog(
  BuildContext context, {
  required String propertyId,
  required String propertyName,
  required String room,
  required String tenantId,
  required String tenantName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ReportIssueDialog(
      propertyId: propertyId,
      propertyName: propertyName,
      room: room,
      tenantId: tenantId,
      tenantName: tenantName,
    ),
  );
}

class _ReportIssueDialog extends ConsumerStatefulWidget {
  const _ReportIssueDialog({
    required this.propertyId,
    required this.propertyName,
    required this.room,
    required this.tenantId,
    required this.tenantName,
  });

  final String propertyId;
  final String propertyName;
  final String room;
  final String tenantId;
  final String tenantName;

  @override
  ConsumerState<_ReportIssueDialog> createState() =>
      _ReportIssueDialogState();
}

class _ReportIssueDialogState extends ConsumerState<_ReportIssueDialog> {
  final _titleController = TextEditingController();
  ComplaintCategory _category = ComplaintCategory.plumbing;
  ComplaintSeverity _severity = ComplaintSeverity.medium;
  TimePreference _timePreference = TimePreference.anytime;
  bool _isSaving = false;
  // Generated once for this dialog instance — a double-tap or a retry
  // after `_save` fails reuses the same key, so the backend records it at
  // most once. See `reportComplaint`'s doc comment.
  final String _idempotencyKey = const Uuid().v4();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final failure = await reportComplaint(
      ref,
      propertyId: widget.propertyId,
      propertyName: widget.propertyName,
      room: widget.room,
      tenantId: widget.tenantId,
      tenantName: widget.tenantName,
      category: _category,
      severity: _severity,
      title: _titleController.text,
      timePreference: _timePreference,
      idempotencyKey: _idempotencyKey,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.complaintsReportIssueTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              l10n.complaintRoomAndProperty(widget.room, widget.propertyName),
              style: AppTextStyles.bodySmall.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(l10n.complaintsCategoryLabel, style: AppTextStyles.kicker),
            const SizedBox(height: AppSpacing.space2),
            // Plain Rows of Expanded tiles, 3 per row, rather than a
            // shrink-wrapped GridView — AlertDialog's layout asks its
            // content for intrinsic dimensions (even with `scrollable:
            // true`), which a shrink-wrapping Sliver viewport can never
            // answer ("RenderShrinkWrappingViewport does not support
            // returning intrinsic dimensions"). Row/Expanded has no
            // viewport underneath, so it can't hit that failure mode.
            for (final row in _chunk(ComplaintCategory.values, 3)) ...[
              Row(
                children: [
                  for (final category in row)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: category == row.last
                              ? 0
                              : AppSpacing.space2,
                        ),
                        child: SizedBox(
                          height: 64,
                          child: _CategoryTile(
                            category: category,
                            selected: category == _category,
                            onTap: () =>
                                setState(() => _category = category),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.space2),
            ],
            const SizedBox(height: AppSpacing.space3),
            Text(l10n.complaintsSeverityQuestion, style: AppTextStyles.kicker),
            const SizedBox(height: AppSpacing.space2),
            Row(
              children: [
                for (final severity in ComplaintSeverity.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: severity == ComplaintSeverity.values.last
                            ? 0
                            : AppSpacing.space2,
                      ),
                      child: _SeverityTile(
                        severity: severity,
                        selected: severity == _severity,
                        onTap: () => setState(() => _severity = severity),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: l10n.complaintsWhatsWrongLabel,
              controller: _titleController,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.space3),
            DropdownButtonFormField<TimePreference>(
              isExpanded: true,
              initialValue: _timePreference,
              decoration: InputDecoration(
                labelText: l10n.complaintsPreferredTimeLabel,
              ),
              items: [
                for (final pref in TimePreference.values)
                  DropdownMenuItem(value: pref, child: Text(pref.labelFor(l10n))),
              ],
              onChanged: (value) =>
                  setState(() => _timePreference = value ?? _timePreference),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        PrimaryButton(
          label: l10n.commonSubmit,
          expand: false,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ComplaintCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? context.appColors.accent100
              : theme.colorScheme.surface,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : context.appColors.divider,
          ),
          borderRadius: AppRadius.mdAll,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 18,
              color: selected
                  ? context.appColors.accent700
                  : context.appColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              category.labelFor(AppLocalizations.of(context)),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? context.appColors.accent700
                    : context.appColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityTile extends StatelessWidget {
  const _SeverityTile({
    required this.severity,
    required this.selected,
    required this.onTap,
  });

  final ComplaintSeverity severity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = severity.tone.foreground(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(
            color: selected ? color : context.appColors.divider,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: AppRadius.smAll,
        ),
        child: Text(
          severity.labelFor(AppLocalizations.of(context)),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}
