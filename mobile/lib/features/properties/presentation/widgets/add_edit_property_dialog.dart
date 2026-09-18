import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/properties_providers.dart';
import '../../domain/property.dart';

const _managerOptions = ['Unassigned', 'Ramesh K.', 'Divya S.'];

/// The Add/Edit property dialog from `Properties.dc.html`: name, address,
/// total beds, and a manager assignment.
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
  late String _manager = widget.editing?.managerName ?? _managerOptions.first;
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _bedsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final beds = int.tryParse(_bedsController.text.trim());
    if (name.isEmpty || beds == null || beds <= 0) {
      setState(() => _errorText = 'Enter a name and a valid bed count');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final controller = ref.read(propertiesProvider.notifier);
    final failure = widget.editing == null
        ? await controller.addProperty(
            name: name,
            address: _addressController.text.trim(),
            totalBeds: beds,
            managerName: _manager,
          )
        : await controller.updateProperty(
            widget.editing!.id,
            name: name,
            address: _addressController.text.trim(),
            totalBeds: beds,
            managerName: _manager,
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
    final isEditing = widget.editing != null;
    return AppDialog(
      title: isEditing ? 'Edit property' : 'Add property',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            label: 'Property name',
            controller: _nameController,
            errorText: _errorText,
          ),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(label: 'Address', controller: _addressController),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(
            label: 'Total beds',
            controller: _bedsController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.space3),
          DropdownButtonFormField<String>(
            initialValue: _manager,
            decoration: const InputDecoration(labelText: 'Manager'),
            items: [
              for (final manager in _managerOptions)
                DropdownMenuItem(value: manager, child: Text(manager)),
            ],
            onChanged: (value) => setState(() => _manager = value ?? _manager),
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
