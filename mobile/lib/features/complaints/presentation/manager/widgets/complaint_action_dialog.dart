import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_text_field.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../application/complaints_providers.dart';
import '../../../domain/complaint.dart';
import '../../../domain/complaint_status.dart';

const _assignees = [
  "Self (I'll fix it)",
  'Cleaner',
  'Electrician',
  'Plumber',
  'Outside vendor',
];

/// The Manager's complaint dialog from `Manager Complaints.dc.html` —
/// "delegate" mode for a Reported/Reopened complaint, "view" mode
/// (with a Reassign escape hatch) for a Delegated/Resolved one.
Future<void> showComplaintActionDialog(
  BuildContext context, {
  required Complaint complaint,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ComplaintActionDialog(complaint: complaint),
  );
}

class _ComplaintActionDialog extends ConsumerStatefulWidget {
  const _ComplaintActionDialog({required this.complaint});

  final Complaint complaint;

  @override
  ConsumerState<_ComplaintActionDialog> createState() =>
      _ComplaintActionDialogState();
}

class _ComplaintActionDialogState extends ConsumerState<_ComplaintActionDialog> {
  late bool _delegateMode = widget.complaint.effectiveStatus.needsDelegation;
  late String _assignee = widget.complaint.delegatedTo ?? _assignees.first;
  final _noteController = TextEditingController();
  bool _isBusy = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _delegate() async {
    setState(() => _isBusy = true);
    final failure = await delegateComplaint(
      ref,
      widget.complaint.id,
      assignee: _assignee,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (failure == null) Navigator.of(context).pop();
  }

  Future<void> _resolveNow() async {
    setState(() => _isBusy = true);
    final failure = await resolveComplaint(ref, widget.complaint.id);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (failure == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    final eff = complaint.effectiveStatus;

    return AppDialog(
      title: complaint.title,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${complaint.room} · ${complaint.tenantName} · '
              'prefers ${complaint.timePreference.label}',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            if (_delegateMode) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _assignees.contains(_assignee)
                    ? _assignee
                    : _assignees.first,
                decoration: const InputDecoration(
                  labelText: "Who's handling this?",
                ),
                items: [
                  for (final option in _assignees)
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: (value) =>
                    setState(() => _assignee = value ?? _assignee),
              ),
              const SizedBox(height: AppSpacing.space3),
              AppTextField(
                label: 'Note (optional)',
                controller: _noteController,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                "Ticket auto-closes in 3 days unless the tenant says it's "
                'still not fixed — no need to come back and mark it done.',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 11.5,
                  color: context.appColors.textMuted,
                ),
              ),
            ] else ...[
              Text(
                eff == ComplaintStatus.resolved
                    ? 'Resolved'
                    : 'Delegated to ${complaint.delegatedTo}',
                style: AppTextStyles.rowTitle,
              ),
              const SizedBox(height: 4),
              Text(
                switch (eff) {
                  // `eff == resolved` covers two different real histories —
                  // a delegated ticket that timed out untouched, and one a
                  // manager closed themselves — and they read very
                  // differently to whoever opens this later, so this checks
                  // the stored `status`, not just the computed `eff`.
                  ComplaintStatus.resolved
                      when complaint.status == ComplaintStatus.delegated =>
                    "Closed automatically — tenant didn't report it again.",
                  ComplaintStatus.resolved => 'Marked resolved by you.',
                  _ =>
                    'Auto-resolves in ${complaint.autoResolveDaysLeft}d '
                        "unless the tenant says it's still not fixed.",
                },
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: _delegateMode
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              PrimaryButton(
                label: 'Delegate & done',
                expand: false,
                isLoading: _isBusy,
                onPressed: _delegate,
              ),
            ]
          : [
              // Reassigning only makes sense while the ticket is still
              // open — a resolved one (auto or manual) is done.
              if (eff == ComplaintStatus.delegated)
                TextButton(
                  onPressed: () => setState(() => _delegateMode = true),
                  child: const Text('Reassign'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              if (eff == ComplaintStatus.delegated)
                PrimaryButton(
                  label: 'Mark resolved now',
                  expand: false,
                  isLoading: _isBusy,
                  onPressed: _resolveNow,
                ),
            ],
    );
  }
}
