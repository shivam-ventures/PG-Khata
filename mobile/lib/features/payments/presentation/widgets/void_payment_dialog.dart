import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/danger_button.dart';
import '../../application/payments_providers.dart';
import '../../domain/rent_payment.dart';

/// "Undo this entry" — the correction path for a mis-recorded payment
/// (wrong amount, wrong method, wrong tenant). Puts the period back to
/// Pending/Overdue with the tenant's on-record rent restored, rather than
/// silently editing what was actually entered.
Future<void> showVoidPaymentDialog(
  BuildContext context,
  WidgetRef ref, {
  required RentPayment payment,
}) {
  return AppDialog.show<void>(
    context,
    title: 'Undo this payment?',
    content: Text(
      "This entry for ${payment.tenantName} will be removed and the "
      "period will go back to needing collection. Use this if the "
      'amount, method or tenant was recorded by mistake.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      DangerButton(
        label: 'Undo payment',
        expand: false,
        onPressed: () async {
          Navigator.of(context).pop();
          final failure = await voidPayment(ref, payment.id);
          if (failure != null && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
          }
        },
      ),
    ],
  );
}
