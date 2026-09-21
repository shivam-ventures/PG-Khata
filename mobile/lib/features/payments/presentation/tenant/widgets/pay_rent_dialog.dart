import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_label_formatter.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../application/payments_providers.dart';
import '../../../domain/payment_method.dart';
import '../../../domain/rent_payment.dart';

enum _PayStep { method, processing, success }

/// The Tenant's self-serve "Pay Rent" flow. `Tenant Payments.dc.html`'s own
/// Pay Rent button has no `onClick` at all — no online gateway was ever
/// designed — so this simulates one end-to-end (method → processing →
/// success) rather than actually charging a card, consistent with every
/// other mock in this app until Phase 6 wires a real backend/gateway.
Future<void> showPayRentDialog(
  BuildContext context, {
  required RentPayment payment,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PayRentDialog(payment: payment),
  );
}

class _PayRentDialog extends ConsumerStatefulWidget {
  const _PayRentDialog({required this.payment});

  final RentPayment payment;

  @override
  ConsumerState<_PayRentDialog> createState() => _PayRentDialogState();
}

class _PayRentDialogState extends ConsumerState<_PayRentDialog> {
  _PayStep _step = _PayStep.method;
  PaymentMethod? _method;

  Future<void> _pay() async {
    final method = _method;
    if (method == null) return;
    setState(() => _step = _PayStep.processing);

    // A real gateway round-trip (open UPI intent / authorize card) — here
    // just a delay so the state actually feels like it's doing something.
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    final failure = await recordSelfPayment(
      ref,
      widget.payment.id,
      method: method,
      amount: widget.payment.expectedAmount,
      date: DateTime.now(),
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() => _step = _PayStep.method);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    setState(() => _step = _PayStep.success);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: switch (_step) {
        _PayStep.method => 'Pay Rent',
        _PayStep.processing => 'Processing payment',
        _PayStep.success => 'Payment successful',
      },
      content: switch (_step) {
        _PayStep.method => _MethodStep(
          payment: widget.payment,
          selected: _method,
          onSelected: (method) => setState(() => _method = method),
        ),
        _PayStep.processing => const _ProcessingStep(),
        _PayStep.success => _SuccessStep(payment: widget.payment),
      },
      actions: switch (_step) {
        _PayStep.method => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Pay ${CurrencyFormatter.rupees(widget.payment.amount)}',
            expand: false,
            onPressed: _method == null ? null : _pay,
          ),
        ],
        _PayStep.processing => const [],
        _PayStep.success => [
          PrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      },
    );
  }
}

class _MethodStep extends StatelessWidget {
  const _MethodStep({
    required this.payment,
    required this.selected,
    required this.onSelected,
  });

  final RentPayment payment;
  final PaymentMethod? selected;
  final ValueChanged<PaymentMethod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room ${payment.room} · ${DateLabelFormatter.monthYear(payment.periodMonth)}',
          style: AppTextStyles.bodySmall.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        Text(
          'How would you like to pay?',
          style: AppTextStyles.kicker.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        _MethodTile(
          icon: Icons.qr_code_2,
          label: 'UPI',
          sub: 'Pay via any UPI app',
          selected: selected == PaymentMethod.upi,
          onTap: () => onSelected(PaymentMethod.upi),
        ),
        const SizedBox(height: AppSpacing.space2),
        _MethodTile(
          icon: Icons.credit_card,
          label: 'Card',
          sub: 'Credit or debit card',
          selected: selected == PaymentMethod.card,
          onTap: () => onSelected(PaymentMethod.card),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space3),
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
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? context.appColors.accent700
                  : context.appColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.rowTitle.copyWith(
                      color: selected ? context.appColors.accent700 : null,
                    ),
                  ),
                  Text(
                    sub,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? theme.colorScheme.primary
                  : context.appColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.space4),
          Text(
            "Hang on, we're confirming your payment…",
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.payment});

  final RentPayment payment;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: context.appColors.success, size: 28),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: Text(
                '${CurrencyFormatter.rupees(payment.amount)} paid for '
                '${DateLabelFormatter.monthYear(payment.periodMonth)}',
                style: AppTextStyles.rowTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          "Your rent record has been updated.",
          style: AppTextStyles.bodySmall.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
