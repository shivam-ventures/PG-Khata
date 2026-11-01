import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/announcements_providers.dart';

/// Post a new announcement to one property's current tenants — every
/// tenant there gets notified the moment this saves (`create_announcement`
/// RPC), not just whoever happens to open Home next.
Future<void> showCreateAnnouncementDialog(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required String propertyName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CreateAnnouncementDialog(
      propertyId: propertyId,
      propertyName: propertyName,
    ),
  );
}

class _CreateAnnouncementDialog extends ConsumerStatefulWidget {
  const _CreateAnnouncementDialog({
    required this.propertyId,
    required this.propertyName,
  });

  final String propertyId;
  final String propertyName;

  @override
  ConsumerState<_CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState
    extends ConsumerState<_CreateAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      setState(
        () => _errorText = AppLocalizations.of(context).announcementsErrorEmptyBody,
      );
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    final failure = await createAnnouncement(
      ref,
      propertyId: widget.propertyId,
      title: _titleController.text.trim(),
      body: body,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _isSaving = false;
        _errorText = failure.message;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.announcementsDialogTitle(widget.propertyName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.announcementsNotifyNotice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(
            label: l10n.announcementsTitleFieldLabel,
            controller: _titleController,
          ),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(
            label: l10n.commonMessage,
            controller: _bodyController,
            maxLines: 4,
            errorText: _errorText,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        PrimaryButton(
          label: l10n.commonPost,
          expand: false,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}
