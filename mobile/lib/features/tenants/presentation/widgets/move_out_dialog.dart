import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
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
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Mark as moved out?'),
      content: Text(
        "$tenantName's bed will be freed and their status set to Vacated. This can't be easily undone.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: dialogContext.appColors.danger,
          ),
          onPressed: () async {
            Navigator.of(dialogContext).pop();
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
          child: const Text('Move out'),
        ),
      ],
    ),
  );
}
