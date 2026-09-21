import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_text_field.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../../../shared/widgets/semantic_tone.dart';
import '../../../application/complaints_providers.dart';
import '../../../domain/complaint_category.dart';
import '../../../domain/complaint_severity.dart';
import '../../../domain/time_preference.dart';

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
    return AppDialog(
      title: 'Report an issue',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Room ${widget.room} · ${widget.propertyName}',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            Text('Category', style: AppTextStyles.kicker),
            const SizedBox(height: AppSpacing.space2),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.space2,
              crossAxisSpacing: AppSpacing.space2,
              childAspectRatio: 1.1,
              children: [
                for (final category in ComplaintCategory.values)
                  _CategoryTile(
                    category: category,
                    selected: category == _category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            Text('How urgent is this?', style: AppTextStyles.kicker),
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
              label: "What's wrong, and where?",
              controller: _titleController,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.space3),
            DropdownButtonFormField<TimePreference>(
              isExpanded: true,
              initialValue: _timePreference,
              decoration: const InputDecoration(
                labelText: 'Preferred time to fix',
              ),
              items: [
                for (final pref in TimePreference.values)
                  DropdownMenuItem(value: pref, child: Text(pref.label)),
              ],
              onChanged: (value) =>
                  setState(() => _timePreference = value ?? _timePreference),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Submit',
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
              category.label,
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
          severity.label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}
