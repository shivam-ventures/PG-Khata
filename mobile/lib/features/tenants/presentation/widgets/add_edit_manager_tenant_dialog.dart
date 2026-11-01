import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/document_scan.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/tenants_providers.dart';
import '../../domain/tenant_record.dart';
import '../../domain/tenant_status.dart';

/// The Manager's Add tenant dialog from `Manager Tenants.dc.html` — simpler
/// than the Owner's: no property picker (the Manager's current PG is
/// implicit) and no joining-date/status fields.
Future<void> showAddManagerTenantDialog(
  BuildContext context, {
  required String propertyId,
  required String propertyName,
  String? initialRoomBed,
  PendingTenant? pending,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AddManagerTenantDialog(
      propertyId: propertyId,
      propertyName: propertyName,
      initialRoomBed: initialRoomBed,
      pending: pending,
    ),
  );
}

class _AddManagerTenantDialog extends ConsumerStatefulWidget {
  const _AddManagerTenantDialog({
    required this.propertyId,
    required this.propertyName,
    this.initialRoomBed,
    this.pending,
  });

  final String propertyId;
  final String propertyName;
  final String? initialRoomBed;
  final PendingTenant? pending;

  @override
  ConsumerState<_AddManagerTenantDialog> createState() =>
      _AddManagerTenantDialogState();
}

class _AddManagerTenantDialogState
    extends ConsumerState<_AddManagerTenantDialog> {
  late final _nameController = TextEditingController(
    text: widget.pending?.name ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.pending?.phone ?? '',
  );
  late final _roomController = TextEditingController(
    text: widget.initialRoomBed ?? '',
  );
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  bool _isSaving = false;
  String? _errorText;

  bool get _isAssignMode => widget.pending != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _roomController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _scanDocument() async {
    final scanned = await pickAndScanTenantDocument(context);
    if (scanned == null || !mounted) return;
    setState(() {
      _nameController.text = scanned.name;
      _phoneController.text = scanned.phone;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final room = _roomController.text.trim();
    final rent = int.tryParse(_rentController.text.trim());
    final phone = _phoneController.text.trim();
    final depositText = _depositController.text.trim();
    final deposit = depositText.isEmpty ? null : int.tryParse(depositText);
    if (room.isEmpty || rent == null || rent <= 0) {
      setState(() => _errorText = l10n.tenantsErrorRoomBedAndRent);
      return;
    }
    if (!_isAssignMode && phone.isEmpty) {
      // Without a phone, this tenant can never sign in and see their own
      // rent/complaints — the app matches a signed-in session to its
      // tenancy by phone (see `currentTenantRecordProvider`).
      setState(() => _errorText = l10n.tenantsErrorPhoneRequired);
      return;
    }
    if (depositText.isNotEmpty && (deposit == null || deposit < 0)) {
      setState(() => _errorText = l10n.tenantsErrorDepositAmount);
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final failure = _isAssignMode
        ? await assignPendingTenant(
            ref,
            widget.pending!.id,
            propertyId: widget.propertyId,
            roomBed: room,
            rent: rent,
            joinedDate: DateTime.now(),
            depositAmount: deposit,
          )
        : await addTenant(
            ref,
            name: _nameController.text.trim(),
            phone: phone,
            propertyId: widget.propertyId,
            propertyName: widget.propertyName,
            roomBed: room,
            rent: rent,
            joinedDate: DateTime.now(),
            status: TenantStatus.active,
            depositAmount: deposit,
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
      title: _isAssignMode
          ? l10n.tenantsAssignBedToTenantTitle
          : l10n.tenantsAddTenant,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isAssignMode) ...[
            InkWell(
              onTap: _scanDocument,
              child: Row(
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    size: 18,
                    color: context.appColors.accent700,
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Text(
                    l10n.tenantsScanInstead,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.accent700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
          ],
          AppTextField(
            label: l10n.tenantsFullNameLabel,
            controller: _nameController,
            errorText: _errorText,
          ),
          const SizedBox(height: AppSpacing.space3),
          if (!_isAssignMode) ...[
            AppTextField(
              label: l10n.commonPhone,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.space3),
          ],
          AppTextField(label: l10n.tenantsRoomBedLabel, controller: _roomController),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(
            label: l10n.tenantsMonthlyRentLabel,
            controller: _rentController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(
            label: l10n.tenantsSecurityDepositLabel,
            controller: _depositController,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        PrimaryButton(
          label: l10n.commonSave,
          expand: false,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}
