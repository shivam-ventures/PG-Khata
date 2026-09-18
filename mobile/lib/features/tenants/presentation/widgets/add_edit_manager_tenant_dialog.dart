import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_text_field.dart';
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
  late final _roomController = TextEditingController(
    text: widget.initialRoomBed ?? '',
  );
  final _rentController = TextEditingController();
  bool _isSaving = false;
  String? _errorText;

  bool get _isAssignMode => widget.pending != null;

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final room = _roomController.text.trim();
    final rent = int.tryParse(_rentController.text.trim());
    if (room.isEmpty || rent == null || rent <= 0) {
      setState(() => _errorText = 'Enter a room/bed and a valid rent amount');
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
          )
        : await addTenant(
            ref,
            name: _nameController.text.trim(),
            phone: '',
            propertyId: widget.propertyId,
            propertyName: widget.propertyName,
            roomBed: room,
            rent: rent,
            joinedDate: DateTime.now(),
            status: TenantStatus.active,
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
      title: _isAssignMode ? 'Assign bed to tenant' : 'Add tenant',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            label: 'Full name',
            controller: _nameController,
            errorText: _errorText,
          ),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(label: 'Room / Bed', controller: _roomController),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(
            label: 'Monthly rent',
            controller: _rentController,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(label: 'Save', isLoading: _isSaving, onPressed: _save),
      ],
    );
  }
}
