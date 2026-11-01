import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/properties_providers.dart';
import '../../domain/property.dart';

const _unassignedValue = '__unassigned__';
const _newManagerValue = '__new__';

/// The Add/Edit property dialog from `Properties.dc.html`: name, address,
/// total beds, and a real manager assignment (picked from managers already
/// active elsewhere in the org, or a brand-new one invited by phone) —
/// replaces the earlier hardcoded 3-name dropdown, which never persisted
/// anything real.
Future<void> showAddEditPropertyDialog(
  BuildContext context, {
  Property? editing,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AddEditPropertyDialog(editing: editing),
  );
}

class _AddEditPropertyDialog extends ConsumerStatefulWidget {
  const _AddEditPropertyDialog({this.editing});

  final Property? editing;

  @override
  ConsumerState<_AddEditPropertyDialog> createState() =>
      _AddEditPropertyDialogState();
}

class _AddEditPropertyDialogState
    extends ConsumerState<_AddEditPropertyDialog> {
  late final _nameController = TextEditingController(
    text: widget.editing?.name ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.editing?.address ?? '',
  );
  late final _bedsController = TextEditingController(
    text: widget.editing?.totalBeds.toString() ?? '',
  );
  final _newManagerNameController = TextEditingController();
  final _newManagerPhoneController = TextEditingController();
  late String _managerSelection =
      widget.editing?.managerId ?? _unassignedValue;
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _bedsController.dispose();
    _newManagerNameController.dispose();
    _newManagerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final beds = int.tryParse(_bedsController.text.trim());
    if (name.isEmpty || beds == null || beds <= 0) {
      setState(() => _errorText = l10n.propertiesErrorNameAndBeds);
      return;
    }
    final isInvitingNew = _managerSelection == _newManagerValue;
    final newManagerName = _newManagerNameController.text.trim();
    final newManagerPhone = _newManagerPhoneController.text.trim();
    if (isInvitingNew && (newManagerName.isEmpty || newManagerPhone.isEmpty)) {
      setState(() => _errorText = l10n.propertiesErrorNewManagerDetails);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final controller = ref.read(propertiesProvider.notifier);
    final String propertyId;
    if (widget.editing == null) {
      final addFailure = await controller.addProperty(
        name: name,
        address: _addressController.text.trim(),
        totalBeds: beds,
      );
      if (!mounted) return;
      if (addFailure != null) {
        setState(() {
          _isSaving = false;
          _errorText = addFailure.message;
        });
        return;
      }
      // addProperty appended the new row last — no id is returned directly
      // to this dialog, so read it back off the now-updated list.
      propertyId = ref.read(propertiesProvider).requireValue.last.id;
    } else {
      propertyId = widget.editing!.id;
      final updateFailure = await controller.updateProperty(
        propertyId,
        name: name,
        address: _addressController.text.trim(),
        totalBeds: beds,
      );
      if (!mounted) return;
      if (updateFailure != null) {
        setState(() {
          _isSaving = false;
          _errorText = updateFailure.message;
        });
        return;
      }
    }

    final managerFailure = await _applyManagerSelection(controller, propertyId);
    if (!mounted) return;
    if (managerFailure != null) {
      setState(() {
        _isSaving = false;
        _errorText = managerFailure.message;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  Future<AppFailure?> _applyManagerSelection(
    PropertiesController controller,
    String propertyId,
  ) async {
    final currentManagerId = widget.editing?.managerId;
    switch (_managerSelection) {
      case _unassignedValue:
        if (currentManagerId == null) return null;
        return controller.unassignManager(propertyId, currentManagerId);
      case _newManagerValue:
        return controller.assignManager(
          propertyId,
          newManagerName: _newManagerNameController.text.trim(),
          newManagerPhone: _newManagerPhoneController.text.trim(),
        );
      default:
        if (_managerSelection == currentManagerId) return null;
        return controller.assignManager(
          propertyId,
          existingManagerId: _managerSelection,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.editing != null;
    final orgManagersAsync = ref.watch(orgManagersProvider);
    return AppDialog(
      title: isEditing ? l10n.propertiesEditPgTitle : l10n.ownerAddPg,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: l10n.propertiesPgNameLabel,
            controller: _nameController,
            errorText: _errorText,
          ),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(label: l10n.commonAddress, controller: _addressController),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(
            label: l10n.propertiesTotalBedsLabel,
            controller: _bedsController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.space3),
          AsyncValueView(
            value: orgManagersAsync,
            loading: (_) => const LinearProgressIndicator(),
            data: (context, managers) => DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: managers.any((m) => m.id == _managerSelection)
                  ? _managerSelection
                  : _unassignedValue,
              decoration: InputDecoration(labelText: l10n.roleManager),
              items: [
                DropdownMenuItem(
                  value: _unassignedValue,
                  child: Text(l10n.propertiesUnassigned),
                ),
                for (final manager in managers)
                  DropdownMenuItem(value: manager.id, child: Text(manager.name)),
                DropdownMenuItem(
                  value: _newManagerValue,
                  child: Text(l10n.propertiesInviteNewManager),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _managerSelection = value ?? _managerSelection),
            ),
          ),
          if (_managerSelection == _newManagerValue) ...[
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: l10n.propertiesNewManagerNameLabel,
              controller: _newManagerNameController,
            ),
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: l10n.propertiesNewManagerPhoneLabel,
              controller: _newManagerPhoneController,
              keyboardType: TextInputType.phone,
            ),
          ],
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
