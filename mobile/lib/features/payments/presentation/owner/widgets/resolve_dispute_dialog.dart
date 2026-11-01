import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_text_field.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../application/payments_providers.dart';
import '../../../domain/rent_payment.dart';

/// Owner-only close-out of a disputed payment — `docs/backend-domain-model.md`
/// §12.6: either the Owner sides with staff's claim (marks it paid) or with
/// the tenant (voids it back to pending/overdue), and either way has to
/// leave a note explaining why. A Manager never sees this dialog — they're
/// the one whose claim is in question, a conflict of interest the RPC
/// itself refuses regardless of what the client shows.
Future<void> showResolveDisputeDialog(
  BuildContext context,
  WidgetRef ref, {
  required RentPayment payment,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ResolveDisputeDialog(payment: payment),
  );
}

class _ResolveDisputeDialog extends ConsumerStatefulWidget {
  const _ResolveDisputeDialog({required this.payment});

  final RentPayment payment;

  @override
  ConsumerState<_ResolveDisputeDialog> createState() =>
      _ResolveDisputeDialogState();
}

class _ResolveDisputeDialogState
    extends ConsumerState<_ResolveDisputeDialog> {
  final _noteController = TextEditingController();
  bool? _outcomePaid;
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_outcomePaid == null) {
      setState(() => _errorText = l10n.paymentsErrorChooseOutcome);
      return;
    }
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      setState(() => _errorText = l10n.paymentsErrorNoteRequired);
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    final failure = await resolveDispute(
      ref,
      widget.payment.id,
      paid: _outcomePaid!,
      note: note,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _isSaving = false;
        _errorText = failure.message;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.paymentsResolveDisputeTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.paymentsDisputeQuestion(
              widget.payment.tenantName,
              widget.payment.method?.labelFor(l10n) ?? '',
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.paymentsDisputeStaffRight),
            value: true,
            groupValue: _outcomePaid,
            onChanged: (value) => setState(() => _outcomePaid = value),
          ),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.paymentsDisputeTenantRight),
            value: false,
            groupValue: _outcomePaid,
            onChanged: (value) => setState(() => _outcomePaid = value),
          ),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(
            label: l10n.paymentsNoteRequiredLabel,
            controller: _noteController,
            maxLines: 3,
            errorText: _errorText,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        PrimaryButton(
          label: l10n.paymentsResolve,
          expand: false,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}
