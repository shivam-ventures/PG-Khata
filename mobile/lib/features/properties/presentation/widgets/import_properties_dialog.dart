import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/csv_file_picker.dart';
import '../../../../core/utils/csv_parser.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/properties_providers.dart';
import '../../domain/property_import_row.dart';

enum _ImportStep { pickFile, review, importing, done }

/// Bulk-adds properties from a CSV (Name, Address, Total Beds, Manager
/// Name) — the Owner Dashboard's "Import from Excel" button never had a
/// flow behind it in the approved design, so this is built from scratch:
/// pick a file → review the parsed rows → confirm.
Future<void> showImportPropertiesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ImportPropertiesDialog(),
  );
}

class _ImportPropertiesDialog extends ConsumerStatefulWidget {
  const _ImportPropertiesDialog();

  @override
  ConsumerState<_ImportPropertiesDialog> createState() =>
      _ImportPropertiesDialogState();
}

class _ImportPropertiesDialogState
    extends ConsumerState<_ImportPropertiesDialog> {
  _ImportStep _step = _ImportStep.pickFile;
  List<ParsedPropertyRow> _rows = [];
  String? _pickError;
  int _importedCount = 0;

  List<ParsedPropertyRow> get _validRows => _rows.where((r) => r.isValid).toList();

  Future<void> _pickFile() async {
    setState(() => _pickError = null);
    final contents = await pickCsvFileContents();
    if (contents == null || !mounted) return;
    final parsedRows = parseCsvRows(contents).map(parsePropertyRow).toList();
    if (parsedRows.isEmpty) {
      setState(() => _pickError = "That file didn't have any rows to import.");
      return;
    }
    setState(() {
      _rows = parsedRows;
      _step = _ImportStep.review;
    });
  }

  Future<void> _confirmImport() async {
    setState(() => _step = _ImportStep.importing);
    var imported = 0;
    for (final row in _validRows) {
      final failure = await ref
          .read(propertiesProvider.notifier)
          .addProperty(
            name: row.name,
            address: row.address,
            totalBeds: row.totalBeds!,
            managerName: row.managerName,
          );
      if (failure == null) imported++;
    }
    if (!mounted) return;
    setState(() {
      _importedCount = imported;
      _step = _ImportStep.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Import PGs',
      content: switch (_step) {
        _ImportStep.pickFile => _PickFileStep(error: _pickError),
        _ImportStep.review => _ReviewStep(rows: _rows),
        _ImportStep.importing => const _ImportingStep(),
        _ImportStep.done => _DoneStep(count: _importedCount),
      },
      actions: switch (_step) {
        _ImportStep.pickFile => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Choose CSV file',
            expand: false,
            onPressed: _pickFile,
          ),
        ],
        _ImportStep.review => [
          TextButton(
            onPressed: () => setState(() => _step = _ImportStep.pickFile),
            child: const Text('Back'),
          ),
          PrimaryButton(
            label: 'Import ${_validRows.length} PGs',
            expand: false,
            onPressed: _validRows.isEmpty ? null : _confirmImport,
          ),
        ],
        _ImportStep.importing => const [],
        _ImportStep.done => [
          PrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      },
    );
  }
}

class _PickFileStep extends StatelessWidget {
  const _PickFileStep({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload a CSV file with one PG per row.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          'Expected columns: Name, Address, Total Beds, Manager Name.',
          style: AppTextStyles.bodySmall.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.space3),
          Text(
            error!,
            style: AppTextStyles.bodySmall.copyWith(color: context.appColors.danger),
          ),
        ],
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.rows});

  final List<ParsedPropertyRow> rows;

  @override
  Widget build(BuildContext context) {
    final validCount = rows.where((r) => r.isValid).length;
    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Found ${rows.length} rows — $validCount ready to import.',
            style: AppTextStyles.bodySmall.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          row.isValid ? Icons.check_circle : Icons.error_outline,
                          size: 16,
                          color: row.isValid
                              ? context.appColors.success
                              : context.appColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                row.name.isEmpty ? '(no name)' : row.name,
                                style: AppTextStyles.rowTitle,
                              ),
                              Text(
                                row.isValid
                                    ? '${row.address} · ${row.totalBeds} beds · ${row.managerName}'
                                    : row.error!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: row.isValid
                                      ? context.appColors.textMuted
                                      : context.appColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportingStep extends StatelessWidget {
  const _ImportingStep();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.space6),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, color: context.appColors.success),
        const SizedBox(width: AppSpacing.space2),
        Expanded(
          child: Text('$count PGs imported.', style: AppTextStyles.rowTitle),
        ),
      ],
    );
  }
}
