import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/rooms_providers.dart';
import '../../domain/sharing_type.dart';

/// The Add Room dialog from `Owner Rooms.dc.html` — Owner-only; Manager
/// Rooms has no equivalent action in the approved design.
Future<void> showAddRoomDialog(
  BuildContext context, {
  required String propertyId,
  required List<String> floorNames,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _AddRoomDialog(propertyId: propertyId, floorNames: floorNames),
  );
}

class _AddRoomDialog extends ConsumerStatefulWidget {
  const _AddRoomDialog({required this.propertyId, required this.floorNames});

  final String propertyId;
  final List<String> floorNames;

  @override
  ConsumerState<_AddRoomDialog> createState() => _AddRoomDialogState();
}

class _AddRoomDialogState extends ConsumerState<_AddRoomDialog> {
  final _numberController = TextEditingController();
  final _rentController = TextEditingController();
  late String _floor = widget.floorNames.isNotEmpty
      ? widget.floorNames.first
      : 'Ground Floor';
  SharingType _sharing = SharingType.triple;
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _numberController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final number = _numberController.text.trim();
    final rent = int.tryParse(_rentController.text.trim());
    if (number.isEmpty || rent == null || rent <= 0) {
      setState(
        () => _errorText = 'Enter a room number and a valid rent amount',
      );
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final failure = await addRoom(
      ref,
      widget.propertyId,
      floor: _floor,
      number: number,
      sharingType: _sharing,
      rentPerBed: rent,
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
      title: 'Add room',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            label: 'Room number',
            controller: _numberController,
            errorText: _errorText,
          ),
          const SizedBox(height: AppSpacing.space3),
          DropdownButtonFormField<String>(
            initialValue: _floor,
            decoration: const InputDecoration(labelText: 'Floor'),
            items: [
              for (final floor in {...widget.floorNames, _floor})
                DropdownMenuItem(value: floor, child: Text(floor)),
            ],
            onChanged: (value) => setState(() => _floor = value ?? _floor),
          ),
          const SizedBox(height: AppSpacing.space3),
          DropdownButtonFormField<SharingType>(
            initialValue: _sharing,
            decoration: const InputDecoration(labelText: 'Sharing type'),
            items: [
              for (final type in SharingType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) => setState(() => _sharing = value ?? _sharing),
          ),
          const SizedBox(height: AppSpacing.space3),
          AppTextField(
            label: 'Rent per bed',
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
