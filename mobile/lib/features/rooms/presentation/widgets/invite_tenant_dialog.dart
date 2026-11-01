import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../onboarding/application/onboarding_providers.dart';

/// The "Invite via link" dialog from `Manager Rooms.dc.html`: a bed-specific
/// link a Manager can copy or share, opening straight into the real
/// `/join/:token` self-serve signup flow — backed by the `create_invite_link`
/// RPC (`docs/backend-domain-model.md` §9), not a placeholder string.
Future<void> showInviteTenantDialog(
  BuildContext context, {
  required String bedId,
  required String room,
  required String bed,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _InviteTenantDialog(
      bedId: bedId,
      room: room,
      bed: bed,
    ),
  );
}

class _InviteTenantDialog extends ConsumerStatefulWidget {
  const _InviteTenantDialog({
    required this.bedId,
    required this.room,
    required this.bed,
  });

  final String bedId;
  final String room;
  final String bed;

  @override
  ConsumerState<_InviteTenantDialog> createState() =>
      _InviteTenantDialogState();
}

class _InviteTenantDialogState extends ConsumerState<_InviteTenantDialog> {
  String? _inviteUrl;
  String? _errorText;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _createLink();
  }

  Future<void> _createLink() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    final result = await ref
        .read(onboardingRepositoryProvider)
        .createInviteLink(widget.bedId);
    if (!mounted) return;
    result.when(
      ok: (token) => setState(() {
        _inviteUrl = 'https://pgkhata.app/join/$token';
        _isLoading = false;
      }),
      err: (failure) => setState(() {
        _errorText = failure.message;
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.roomsInviteTitle(widget.room, widget.bed),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.roomsInviteBody,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.appColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.space3),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorText != null) ...[
            Text(
              _errorText!,
              style: TextStyle(color: context.appColors.danger700),
            ),
            const SizedBox(height: AppSpacing.space2),
            SecondaryButton(label: l10n.commonTryAgain, onPressed: _createLink),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.space3),
              decoration: BoxDecoration(
                color: context.appColors.surfaceAlt,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(_inviteUrl!, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: AppSpacing.space3),
            SecondaryButton(
              label: l10n.roomsCopyLink,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _inviteUrl!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.roomsLinkCopied)),
                  );
                }
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
