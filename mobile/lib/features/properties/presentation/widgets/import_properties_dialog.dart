import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/csv_file_picker.dart';
import '../../../../core/utils/csv_parser.dart';
import '../../../../l10n/app_localizations.dart';
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
      setState(
        () => _pickError = AppLocalizations.of(context).propertiesImportNoRowsError,
      );
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
      // row.managerName is validated but not assignable from a CSV alone
      // (a real assignment needs a phone number, not just a name) — bulk
      // import creates properties unassigned; assign a real manager per
      // property afterwards from Edit PG.
      final failure = await ref
          .read(propertiesProvider.notifier)
          .addProperty(
            name: row.name,
            address: row.address,
            totalBeds: row.totalBeds!,
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
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.propertiesImportPgsTitle,
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
            child: Text(l10n.commonCancel),
          ),
          PrimaryButton(
            label: l10n.propertiesChooseCsvFile,
            expand: false,
            onPressed: _pickFile,
          ),
        ],
        _ImportStep.review => [
          TextButton(
            onPressed: () => setState(() => _step = _ImportStep.pickFile),
            child: Text(l10n.commonBack),
          ),
          PrimaryButton(
            label: l10n.propertiesImportCount(_validRows.length),
            expand: false,
            onPressed: _validRows.isEmpty ? null : _confirmImport,
          ),
        ],
        _ImportStep.importing => const [],
        _ImportStep.done => [
          PrimaryButton(
            label: l10n.commonDone,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.propertiesUploadCsvInstructions,
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          l10n.propertiesExpectedColumns,
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
    final l10n = AppLocalizations.of(context);
    final validCount = rows.where((r) => r.isValid).length;
    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.propertiesFoundRows(rows.length, validCount),
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
                                row.name.isEmpty
                                    ? l10n.propertiesNoNamePlaceholder
                                    : row.name,
                                style: AppTextStyles.rowTitle,
                              ),
                              Text(
                                row.isValid
                                    ? l10n.propertiesRowSummary(
                                        row.address,
                                        row.totalBeds!,
                                        row.managerName,
                                      )
                                    : row.error!.labelFor(l10n),
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
          child: Text(
            AppLocalizations.of(context).propertiesImportedCount(count),
            style: AppTextStyles.rowTitle,
          ),
        ),
      ],
    );
  }
}
