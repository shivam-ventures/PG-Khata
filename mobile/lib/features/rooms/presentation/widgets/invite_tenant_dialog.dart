import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/secondary_button.dart';

/// The "Invite via link" dialog from `Manager Rooms.dc.html`: a bed-specific
/// link a Manager can copy or share, rather than a stored/expiring entity —
/// see `docs/domain-model-notes.md`'s open question on whether that's ever
/// needed. The link isn't a real route yet (self-registration is out of
/// scope, per the reconciliation doc), so it's shown for the copy/share
/// affordance only.
Future<void> showInviteTenantDialog(
  BuildContext context, {
  required String propertyId,
  required String room,
  required String bed,
}) {
  final inviteUrl = 'https://pgkhata.app/join/$propertyId-$room-$bed';
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: 'Invite tenant to Room $room, Bed $bed',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Send this link — opening it drops the tenant straight into signup, already linked to this bed. No code to type, no risk of joining the wrong PG.",
            style: Theme.of(dialogContext).textTheme.bodySmall
                ?.copyWith(color: dialogContext.appColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.space3),
          Container(
            padding: const EdgeInsets.all(AppSpacing.space3),
            decoration: BoxDecoration(
              color: dialogContext.appColors.surfaceAlt,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(inviteUrl, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: AppSpacing.space3),
          SecondaryButton(
            label: 'Copy link',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteUrl));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext)
                    .showSnackBar(const SnackBar(content: Text('Link copied')));
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
