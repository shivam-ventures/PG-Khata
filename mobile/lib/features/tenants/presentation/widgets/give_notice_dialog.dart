import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_label_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/tenants_providers.dart';

/// Starts a tenancy's notice period — 15 days' notice is required
/// (`request_move_out` on the backend, `evaluate_move_out_notice`'s single
/// source of truth for the policy); picking a sooner date needs an
/// explicit "forfeit the deposit and proceed anyway" acknowledgment rather
/// than being a dead end.
Future<void> showGiveNoticeDialog(
  BuildContext context,
  WidgetRef ref, {
  required String tenantId,
  required String tenantName,
  required String propertyId,
  required bool hasDeposit,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _GiveNoticeDialog(
      tenantId: tenantId,
      tenantName: tenantName,
      propertyId: propertyId,
      hasDeposit: hasDeposit,
    ),
  );
}

class _GiveNoticeDialog extends ConsumerStatefulWidget {
  const _GiveNoticeDialog({
    required this.tenantId,
    required this.tenantName,
    required this.propertyId,
    required this.hasDeposit,
  });

  final String tenantId;
  final String tenantName;
  final String propertyId;
  final bool hasDeposit;

  @override
  ConsumerState<_GiveNoticeDialog> createState() => _GiveNoticeDialogState();
}

class _GiveNoticeDialogState extends ConsumerState<_GiveNoticeDialog> {
  // Advisory only — a best-effort guess so the dialog can show a live
  // "meets/short notice" hint and the forfeiture checkbox proactively as
  // the user picks a date, without a round-trip on every tap. The
  // backend's `minimum_notice_days()` (migration 37) is the actual,
  // authoritative source: `_submit` never blocks locally on this value —
  // it always attempts the call, and a mismatch here (if the policy is
  // ever changed server-side) just means the checkbox appears one
  // round-trip later than it ideally would, driven by the real rejection
  // instead. See the pre-launch audit, P2-4.
  static const _advisoryMinimumNoticeDays = 15;

  late DateTime _moveOutDate = DateTime.now().add(
    const Duration(days: _advisoryMinimumNoticeDays),
  );
  bool _acknowledgeForfeiture = false;
  bool _isSaving = false;
  bool _showForfeitureCheckbox = false;
  String? _errorText;

  int get _noticeDays =>
      DateTime(
        _moveOutDate.year,
        _moveOutDate.month,
        _moveOutDate.day,
      ).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;

  bool get _isAdvisoryShortNotice => _noticeDays < _advisoryMinimumNoticeDays;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveOutDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _moveOutDate = picked;
        if (!_isAdvisoryShortNotice) {
          _acknowledgeForfeiture = false;
          _showForfeitureCheckbox = false;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_showForfeitureCheckbox &&
        widget.hasDeposit &&
        !_acknowledgeForfeiture) {
      setState(
        () => _errorText = AppLocalizations.of(context).tenantsForfeitureError,
      );
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    final failure = await requestMoveOut(
      ref,
      widget.tenantId,
      propertyId: widget.propertyId,
      moveOutDate: _moveOutDate,
      acknowledgeForfeiture: _acknowledgeForfeiture,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _isSaving = false;
        _errorText = failure.message;
        // The server just told us this is short notice — reveal the
        // acknowledgment checkbox even if the local advisory guess hadn't
        // shown it yet (e.g. the policy threshold changed server-side).
        if (failure is ShortNoticeFailure) _showForfeitureCheckbox = true;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Shown if either the local advisory guess or a real server rejection
    // says this is short notice — see the field doc comments above.
    final showForfeitureCheckbox =
        _showForfeitureCheckbox || _isAdvisoryShortNotice;
    return AppDialog(
      title: l10n.tenantsGiveNoticeTitle(widget.tenantName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tenantsMoveOutDateLabel,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.space1),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space3,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: context.appColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(DateLabelFormatter.format(_moveOutDate)),
                  ),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            _isAdvisoryShortNotice
                ? l10n.tenantsNoticeShort(_noticeDays, _advisoryMinimumNoticeDays)
                : l10n.tenantsNoticeMeets(_noticeDays, _advisoryMinimumNoticeDays),
            style: AppTextStyles.bodySmall.copyWith(
              color: _isAdvisoryShortNotice
                  ? context.appColors.danger700
                  : context.appColors.success700,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showForfeitureCheckbox && widget.hasDeposit) ...[
            const SizedBox(height: AppSpacing.space3),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _acknowledgeForfeiture,
              onChanged: (value) => setState(() {
                _acknowledgeForfeiture = value ?? false;
                _errorText = null;
              }),
              title: Text(
                l10n.tenantsForfeitureAck,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: AppSpacing.space2),
            Text(
              _errorText!,
              style: TextStyle(color: context.appColors.danger700, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        PrimaryButton(
          label: l10n.tenantsGiveNoticeButton,
          expand: false,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }
}
