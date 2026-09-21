import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/document_scan.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../properties/domain/property.dart';
import '../../application/tenants_providers.dart';
import '../../domain/tenant_record.dart';
import '../../domain/tenant_status.dart';

/// The Owner's Add tenant dialog from `Owner Tenants.dc.html`. When
/// [pending] is given, this is the "Assign bed & rent" mode for a
/// self-registered person instead of a from-scratch add.
Future<void> showAddOwnerTenantDialog(
  BuildContext context, {
  required List<Property> properties,
  PendingTenant? pending,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _AddOwnerTenantDialog(properties: properties, pending: pending),
  );
}

class _AddOwnerTenantDialog extends ConsumerStatefulWidget {
  const _AddOwnerTenantDialog({required this.properties, this.pending});

  final List<Property> properties;
  final PendingTenant? pending;

  @override
  ConsumerState<_AddOwnerTenantDialog> createState() =>
      _AddOwnerTenantDialogState();
}

class _AddOwnerTenantDialogState extends ConsumerState<_AddOwnerTenantDialog> {
  late final _nameController = TextEditingController(
    text: widget.pending?.name ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.pending?.phone ?? '',
  );
  late final _roomBedController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  late String _propertyId =
      widget.pending?.propertyId ??
      (widget.properties.isNotEmpty ? widget.properties.first.id : '');
  DateTime _joinedDate = DateTime.now();
  TenantStatus _status = TenantStatus.active;
  bool _isSaving = false;
  String? _errorText;

  bool get _isAssignMode => widget.pending != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _roomBedController.dispose();
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

  Future<void> _pickJoinedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _joinedDate = picked);
  }

  Future<void> _save() async {
    final roomBed = _roomBedController.text.trim();
    final rent = int.tryParse(_rentController.text.trim());
    final depositText = _depositController.text.trim();
    final deposit = depositText.isEmpty ? null : int.tryParse(depositText);
    if (roomBed.isEmpty || rent == null || rent <= 0) {
      setState(() => _errorText = 'Enter a room/bed and a valid rent amount');
      return;
    }
    if (depositText.isNotEmpty && (deposit == null || deposit < 0)) {
      setState(() => _errorText = 'Enter a valid deposit amount, or leave it blank');
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
            propertyId: widget.pending!.propertyId,
            roomBed: roomBed,
            rent: rent,
            joinedDate: _joinedDate,
            depositAmount: deposit,
          )
        : await addTenant(
            ref,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            propertyId: _propertyId,
            propertyName: widget.properties
                .firstWhere((p) => p.id == _propertyId)
                .name,
            roomBed: roomBed,
            rent: rent,
            joinedDate: _joinedDate,
            status: _status,
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
    return AppDialog(
      title: _isAssignMode ? 'Assign bed & rent' : 'Add tenant',
      content: SingleChildScrollView(
        child: Column(
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
                      'Scan an ID or filled form instead',
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
              label: 'Full name',
              controller: _nameController,
              errorText: _errorText,
            ),
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: 'Phone',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.space3),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: widget.properties.any((p) => p.id == _propertyId)
                  ? _propertyId
                  : null,
              decoration: const InputDecoration(labelText: 'PG'),
              items: [
                for (final property in widget.properties)
                  DropdownMenuItem(
                    value: property.id,
                    child: Text(property.name),
                  ),
              ],
              onChanged: _isAssignMode
                  ? null
                  : (value) =>
                        setState(() => _propertyId = value ?? _propertyId),
            ),
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: 'Room / Bed (e.g. 101 - B)',
              controller: _roomBedController,
            ),
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: 'Monthly rent',
              controller: _rentController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: 'Security deposit (optional)',
              controller: _depositController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.space3),
            InkWell(
              onTap: _pickJoinedDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Joining date'),
                child: Text(
                  '${_joinedDate.year}-${_joinedDate.month.toString().padLeft(2, '0')}-${_joinedDate.day.toString().padLeft(2, '0')}',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            DropdownButtonFormField<TenantStatus>(
              isExpanded: true,
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final status in TenantStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Save',
          expand: false,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}
