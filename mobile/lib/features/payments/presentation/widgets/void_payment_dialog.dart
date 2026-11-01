import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
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
  final l10n = AppLocalizations.of(context);
  return AppDialog.show<void>(
    context,
    title: l10n.paymentsUndoTitle,
    content: Text(l10n.paymentsUndoMessage(payment.tenantName)),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.commonCancel),
      ),
      DangerButton(
        label: l10n.paymentsUndoButton,
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
