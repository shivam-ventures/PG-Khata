import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
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
  late final _amountController = TextEditingController(
    text: widget.payment.expectedAmount.toString(),
  );
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
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'Enter a valid amount');
      return;
    }
    setState(() => _errorText = null);
    if (amount != widget.payment.expectedAmount) {
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
    if (_confirmingMismatch) {
      final amount = int.parse(_amountController.text.trim());
      return AppDialog(
        title: 'Double-check this amount',
        content: Text(
          "${widget.payment.tenantName}'s rent on record is "
          '${CurrencyFormatter.rupees(widget.payment.expectedAmount)}, but '
          "you're about to record ${CurrencyFormatter.rupees(amount)}. "
          'Record this amount anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _confirmingMismatch = false),
            child: const Text('Go back'),
          ),
          PrimaryButton(
            label: 'Yes, record ${CurrencyFormatter.rupees(amount)}',
            expand: false,
            isLoading: _isSaving,
            onPressed: () => _save(amount),
          ),
        ],
      );
    }

    return AppDialog(
      title: 'Collect rent — ${widget.payment.tenantName}',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Amount',
              controller: _amountController,
              keyboardType: TextInputType.number,
              errorText: _errorText,
            ),
            const SizedBox(height: AppSpacing.space3),
            DropdownButtonFormField<PaymentMethod>(
              isExpanded: true,
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Method'),
              items: [
                for (final method in PaymentMethod.values)
                  DropdownMenuItem(value: method, child: Text(method.label)),
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
                'This is marked "Awaiting confirmation" until '
                '${widget.payment.tenantName} confirms it on their end — '
                'staff-recorded payments always need that check, whatever '
                'the method.',
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
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Save',
          expand: false,
          isLoading: _isSaving,
          onPressed: _onSavePressed,
        ),
      ],
    );
  }
}
