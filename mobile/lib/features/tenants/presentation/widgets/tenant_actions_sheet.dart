import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/danger_button.dart';
import '../../application/tenants_providers.dart';
import '../../domain/tenant_record.dart';
import '../../domain/tenant_status.dart';
import 'give_notice_dialog.dart';
import 'move_out_dialog.dart';

/// One tenant now has up to four possible overflow actions (give notice,
/// cancel notice, move out immediately, mark a deposit returned) where it
/// used to have exactly one ("Move out") — a bottom sheet picker replaces
/// the old single always-move-out tap target.
Future<void> showTenantActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required TenantRecord tenant,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tenant.canGiveNotice)
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.tenantsGiveNoticeButton),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showGiveNoticeDialog(
                  context,
                  ref,
                  tenantId: tenant.id,
                  tenantName: tenant.name,
                  propertyId: tenant.propertyId,
                  hasDeposit: tenant.depositAmount != null,
                );
              },
            ),
          if (tenant.canCancelNotice)
            ListTile(
              leading: const Icon(Icons.undo),
              title: Text(l10n.tenantsCancelNotice),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final failure = await cancelMoveOutNotice(
                  ref,
                  tenant.id,
                  propertyId: tenant.propertyId,
                );
                if (failure != null && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(failure.message)));
                }
              },
            ),
          if (tenant.canMoveOut)
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(
                tenant.status == TenantStatus.noticePeriod
                    ? l10n.tenantsMoveOutEndNoticeEarly
                    : l10n.tenantsMoveOutNoNotice,
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showMoveOutDialog(
                  context,
                  ref,
                  tenantId: tenant.id,
                  tenantName: tenant.name,
                  propertyId: tenant.propertyId,
                );
              },
            ),
          if (tenant.canMarkDepositReturned)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(l10n.tenantsMarkDepositReturned),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final confirmed = await AppDialog.show<bool>(
                  context,
                  title: l10n.tenantsMarkDepositReturnedTitle,
                  content: Text(
                    l10n.tenantsMarkDepositReturnedMessage(tenant.name),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.commonCancel),
                    ),
                    DangerButton(
                      label: l10n.commonConfirm,
                      expand: false,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                );
                if (confirmed == true) {
                  final failure = await markDepositReturned(
                    ref,
                    tenant.id,
                    propertyId: tenant.propertyId,
                  );
                  if (failure != null && context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(failure.message)));
                  }
                }
              },
            ),
        ],
      ),
    ),
  );
}
