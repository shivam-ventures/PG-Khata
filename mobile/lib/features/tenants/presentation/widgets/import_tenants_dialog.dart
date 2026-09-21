import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/csv_file_picker.dart';
import '../../../../core/utils/csv_parser.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/tenants_providers.dart';
import '../../domain/tenant_import_row.dart';
import '../../domain/tenant_status.dart';

enum _ImportStep { pickFile, review, importing, done }

/// Bulk-adds tenants from a CSV (Name, Phone, Room/Bed, Rent) for the
/// Manager's current PG — no design ever scoped this, so it mirrors the
/// Owner's property import flow: pick a file → review → confirm.
Future<void> showImportTenantsDialog(
  BuildContext context, {
  required String propertyId,
  required String propertyName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ImportTenantsDialog(
      propertyId: propertyId,
      propertyName: propertyName,
    ),
  );
}

class _ImportTenantsDialog extends ConsumerStatefulWidget {
  const _ImportTenantsDialog({
    required this.propertyId,
    required this.propertyName,
  });

  final String propertyId;
  final String propertyName;

  @override
  ConsumerState<_ImportTenantsDialog> createState() =>
      _ImportTenantsDialogState();
}

class _ImportTenantsDialogState extends ConsumerState<_ImportTenantsDialog> {
  _ImportStep _step = _ImportStep.pickFile;
  List<ParsedTenantRow> _rows = [];
  String? _pickError;
  int _importedCount = 0;

  List<ParsedTenantRow> get _validRows => _rows.where((r) => r.isValid).toList();

  Future<void> _pickFile() async {
    setState(() => _pickError = null);
    final contents = await pickCsvFileContents();
    if (contents == null || !mounted) return;
    final parsedRows = parseCsvRows(contents).map(parseTenantRow).toList();
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
      final failure = await addTenant(
        ref,
        name: row.name,
        phone: row.phone,
        propertyId: widget.propertyId,
        propertyName: widget.propertyName,
        roomBed: row.roomBed,
        rent: row.rent!,
        joinedDate: DateTime.now(),
        status: TenantStatus.active,
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
      title: 'Import tenants',
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
            label: 'Import ${_validRows.length} tenants',
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
          'Upload a CSV file with one tenant per row.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          'Expected columns: Name, Phone, Room/Bed, Rent.',
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

  final List<ParsedTenantRow> rows;

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
                                    ? '${row.roomBed} · ₹${row.rent}${row.phone.isEmpty ? '' : ' · ${row.phone}'}'
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
          child: Text('$count tenants imported.', style: AppTextStyles.rowTitle),
        ),
      ],
    );
  }
}
