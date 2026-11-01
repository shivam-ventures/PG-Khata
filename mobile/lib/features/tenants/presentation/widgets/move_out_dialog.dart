import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/danger_button.dart';
import '../../application/tenants_providers.dart';

/// The "Mark as moved out?" confirmation shared by Owner and Manager
/// Tenants — frees the bed and sets status to Vacated.
Future<void> showMoveOutDialog(
  BuildContext context,
  WidgetRef ref, {
  required String tenantId,
  required String tenantName,
  required String propertyId,
}) {
  final l10n = AppLocalizations.of(context);
  return AppDialog.show<void>(
    context,
    title: l10n.tenantsMoveOutTitle,
    content: Text(l10n.tenantsMoveOutMessage(tenantName)),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.commonCancel),
      ),
      DangerButton(
        label: l10n.tenantsMoveOutButton,
        expand: false,
        onPressed: () async {
          Navigator.of(context).pop();
          final failure = await moveOutTenant(
            ref,
            tenantId,
            propertyId: propertyId,
          );
          if (failure != null && context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(failure.message)));
          }
        },
      ),
    ],
  );
}
