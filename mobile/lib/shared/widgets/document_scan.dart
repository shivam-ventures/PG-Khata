import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'app_dialog.dart';

/// What a scanned document yields — deliberately just the fields the
/// tenant-entry dialogs can actually use (Manager's own dialog has no phone
/// field; each caller fills whichever of its own controllers apply).
@immutable
class ScannedTenantFields {
  const ScannedTenantFields({required this.name, required this.phone});

  final String name;
  final String phone;
}

/// Sample records a "scan" resolves to. There is no real OCR/AI vision call
/// here — per the product decision to hold that cost until Phase 6 gives it
/// a backend to call through, this simulates extraction the same way every
/// other not-yet-backed feature in this app is mocked. Swap this for a real
/// vision-API call once that's approved.
const _sampleScans = [
  ScannedTenantFields(name: 'Amit Verma', phone: '9845123456'),
  ScannedTenantFields(name: 'Sneha Reddy', phone: '9900112233'),
  ScannedTenantFields(name: 'Rohit Malhotra', phone: '9812345678'),
  ScannedTenantFields(name: 'Priya Nair', phone: '9945567890'),
  ScannedTenantFields(name: 'Karan Mehta', phone: '9876123450'),
];

/// Lets the user photograph or upload a document (an ID card, or the
/// manager's own filled paper intake form) as a single-record alternative
/// to typing a tenant in by hand. Returns the "extracted" fields, or null
/// if the user cancelled at any point.
Future<ScannedTenantFields?> pickAndScanTenantDocument(
  BuildContext context,
) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery/files'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;

  XFile? file;
  try {
    file = await ImagePicker().pickImage(source: source, imageQuality: 70);
  } catch (_) {
    file = null;
  }
  if (file == null || !context.mounted) return null;

  return showDialog<ScannedTenantFields>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ScanningDialog(imageFile: file!),
  );
}

class _ScanningDialog extends StatefulWidget {
  const _ScanningDialog({required this.imageFile});

  final XFile imageFile;

  @override
  State<_ScanningDialog> createState() => _ScanningDialogState();
}

class _ScanningDialogState extends State<_ScanningDialog> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    final sample = (_sampleScans.toList()..shuffle()).first;
    Navigator.of(context).pop(sample);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Reading document…',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<Uint8List>(
            future: widget.imageFile.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 120);
              }
              return ClipRRect(
                borderRadius: AppRadius.smAll,
                child: Image.memory(
                  snapshot.data!,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.space4),
          const CircularProgressIndicator(),
        ],
      ),
      actions: const [],
    );
  }
}
