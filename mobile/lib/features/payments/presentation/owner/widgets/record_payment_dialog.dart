import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/utils/currency_formatter.dart';
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
  late final _amountController = TextEditingController(
    text: _selected == null ? '' : _selected!.expectedAmount.toString(),
  );
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
    final selected = _selected;
    final amount = int.tryParse(_amountController.text.trim());
    if (selected == null || amount == null || amount <= 0) {
      setState(() => _errorText = 'Choose a tenant and a valid amount');
      return;
    }
    setState(() => _errorText = null);
    if (amount != selected.expectedAmount) {
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
    if (widget.due.isEmpty) {
      return AppDialog(
        title: 'Record payment',
        content: const EmptyState(
          icon: Icons.check_circle_outline,
          title: 'Everyone is paid up',
          message: 'There\'s no outstanding rent to record right now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    if (_confirmingMismatch) {
      final selected = _selected!;
      final amount = int.parse(_amountController.text.trim());
      return AppDialog(
        title: 'Double-check this amount',
        content: Text(
          "${selected.tenantName}'s rent on record is "
          '${CurrencyFormatter.rupees(selected.expectedAmount)}, but '
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
      title: 'Record payment',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<RentPayment>(
              isExpanded: true,
              initialValue: _selected,
              decoration: const InputDecoration(labelText: 'Tenant'),
              items: [
                for (final payment in widget.due)
                  DropdownMenuItem(
                    value: payment,
                    child: Text(
                      '${payment.tenantName} · ${payment.propertyName} · '
                      '${payment.room}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                _selected = value;
                _amountController.text = value?.expectedAmount.toString() ?? '';
              }),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Amount',
              controller: _amountController,
              keyboardType: TextInputType.number,
              errorText: _errorText,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
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
                'This is marked "Awaiting confirmation" until the tenant '
                'confirms it on their end — staff-recorded payments always '
                'need that check, whatever the method.',
                style: TextStyle(fontSize: 12, color: context.appColors.textMuted),
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
