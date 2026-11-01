import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_text_field.dart';
import '../../../../../shared/widgets/empty_state.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../application/payments_providers.dart';
import '../../../domain/payment_method.dart';
import '../../../domain/rent_payment.dart';

/// The Owner's "Record payment" dialog from `Owner Payments.dc.html`. The
/// tenant dropdown only lists tenants who currently owe rent — recording a
/// payment settles that outstanding period, so there's nothing to record
/// for someone already paid up.
Future<void> showRecordPaymentDialog(
  BuildContext context, {
  required List<RentPayment> payments,
}) {
  final due = payments.where((p) => p.status.isCollectable).toList();
  return showDialog<void>(
    context: context,
    builder: (_) => _RecordPaymentDialog(due: due),
  );
}

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  const _RecordPaymentDialog({required this.due});

  final List<RentPayment> due;

  @override
  ConsumerState<_RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  late RentPayment? _selected = widget.due.isNotEmpty ? widget.due.first : null;
  // Prefill/compare against the remaining balance, not the full rent — for
  // an already-partially-paid period those differ, and prefilling the full
  // amount would make collecting "the rest" always trigger a false
  // mismatch warning.
  late final _amountController = TextEditingController(
    text: _selected == null ? '' : _selected!.outstandingAmount.toString(),
  );
  // Generated once for this dialog instance — a double-tap or a retry
  // after `_save` fails reuses the same key, so the backend records it at
  // most once. See `recordPayment`'s doc comment.
  final String _idempotencyKey = const Uuid().v4();
  PaymentMethod _method = PaymentMethod.upi;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  bool _confirmingMismatch = false;
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _onSavePressed() {
    final l10n = AppLocalizations.of(context);
    final selected = _selected;
    final amount = int.tryParse(_amountController.text.trim());
    if (selected == null || amount == null || amount <= 0) {
      setState(() => _errorText = l10n.paymentsErrorChooseTenantAndAmount);
      return;
    }
    setState(() => _errorText = null);
    if (amount != selected.outstandingAmount) {
      setState(() => _confirmingMismatch = true);
      return;
    }
    _save(amount);
  }

  Future<void> _save(int amount) async {
    final selected = _selected!;
    setState(() => _isSaving = true);
    final failure = await recordPayment(
      ref,
      selected.id,
      method: _method,
      amount: amount,
      date: _date,
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
    if (widget.due.isEmpty) {
      return AppDialog(
        title: l10n.paymentsRecordPaymentTitle,
        content: EmptyState(
          icon: Icons.check_circle_outline,
          title: l10n.paymentsAllPaidUpTitle,
          message: l10n.paymentsAllPaidUpMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      );
    }

    if (_confirmingMismatch) {
      final selected = _selected!;
      final amount = int.parse(_amountController.text.trim());
      return AppDialog(
        title: l10n.paymentsMismatchTitle,
        content: Text(
          l10n.paymentsMismatchMessage(
            selected.tenantName,
            CurrencyFormatter.rupees(selected.outstandingAmount),
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
      title: l10n.paymentsRecordPaymentTitle,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<RentPayment>(
              isExpanded: true,
              initialValue: _selected,
              decoration: InputDecoration(labelText: l10n.commonTenant),
              items: [
                for (final payment in widget.due)
                  DropdownMenuItem(
                    value: payment,
                    child: Text(
                      l10n.paymentsTenantOption(
                        payment.tenantName,
                        payment.propertyName,
                        payment.room,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                _selected = value;
                _amountController.text = value?.outstandingAmount.toString() ?? '';
              }),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: l10n.commonAmount,
              controller: _amountController,
              keyboardType: TextInputType.number,
              errorText: _errorText,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: l10n.commonDate),
                child: Text(
                  '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
                  '${_date.day.toString().padLeft(2, '0')}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.appColors.info100,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                l10n.paymentsAwaitingConfirmationNoticeGeneric,
                style: TextStyle(fontSize: 12, color: context.appColors.textMuted),
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
