import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_text_field.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../application/payments_providers.dart';
import '../../../domain/payment_method.dart';
import '../../../domain/rent_payment.dart';

/// The Manager's "Collect rent" dialog from `Manager Payments.dc.html`.
Future<void> showCollectRentDialog(
  BuildContext context, {
  required RentPayment payment,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CollectRentDialog(payment: payment),
  );
}

class _CollectRentDialog extends ConsumerStatefulWidget {
  const _CollectRentDialog({required this.payment});

  final RentPayment payment;

  @override
  ConsumerState<_CollectRentDialog> createState() =>
      _CollectRentDialogState();
}

class _CollectRentDialogState extends ConsumerState<_CollectRentDialog> {
  // Prefill/compare against the remaining balance, not the full rent — for
  // an already-partially-paid period those differ, and prefilling the full
  // amount would make collecting "the rest" always trigger a false
  // mismatch warning.
  late final _amountController = TextEditingController(
    text: widget.payment.outstandingAmount.toString(),
  );
  // Generated once for this dialog instance (this submit attempt), not per
  // tap of Save — a double-tap or a retry after `_save` fails reuses the
  // same key, so the backend records it at most once. See
  // `recordPayment`'s doc comment.
  final String _idempotencyKey = const Uuid().v4();
  PaymentMethod _method = PaymentMethod.cash;
  bool _isSaving = false;
  bool _confirmingMismatch = false;
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onSavePressed() {
    final l10n = AppLocalizations.of(context);
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorText = l10n.paymentsErrorInvalidAmount);
      return;
    }
    setState(() => _errorText = null);
    if (amount != widget.payment.outstandingAmount) {
      setState(() => _confirmingMismatch = true);
      return;
    }
    _save(amount);
  }

  Future<void> _save(int amount) async {
    setState(() => _isSaving = true);
    final failure = await recordPayment(
      ref,
      widget.payment.id,
      method: _method,
      amount: amount,
      date: DateTime.now(),
      idempotencyKey: _idempotencyKey,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _isSaving = false;
        _confirmingMismatch = false;
        _errorText = failure.message;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_confirmingMismatch) {
      final amount = int.parse(_amountController.text.trim());
      return AppDialog(
        title: l10n.paymentsMismatchTitle,
        content: Text(
          l10n.paymentsMismatchMessage(
            widget.payment.tenantName,
            CurrencyFormatter.rupees(widget.payment.outstandingAmount),
            CurrencyFormatter.rupees(amount),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _confirmingMismatch = false),
            child: Text(l10n.commonGoBack),
          ),
          PrimaryButton(
            label: l10n.paymentsConfirmRecordAmount(
              CurrencyFormatter.rupees(amount),
            ),
            expand: false,
            isLoading: _isSaving,
            onPressed: () => _save(amount),
          ),
        ],
      );
    }

    return AppDialog(
      title: l10n.paymentsCollectRentTitle(widget.payment.tenantName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: l10n.commonAmount,
              controller: _amountController,
              keyboardType: TextInputType.number,
              errorText: _errorText,
            ),
            const SizedBox(height: AppSpacing.space3),
            DropdownButtonFormField<PaymentMethod>(
              isExpanded: true,
              initialValue: _method,
              decoration: InputDecoration(labelText: l10n.commonMethod),
              items: [
                for (final method in PaymentMethod.values)
                  DropdownMenuItem(
                    value: method,
                    child: Text(method.labelFor(l10n)),
                  ),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: AppSpacing.space3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: context.appColors.info100,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                l10n.paymentsAwaitingConfirmationNoticeFor(
                  widget.payment.tenantName,
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: context.appColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        PrimaryButton(
          label: l10n.commonSave,
          expand: false,
          isLoading: _isSaving,
          onPressed: _onSavePressed,
        ),
      ],
    );
  }
}
