import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// Opens the platform file picker for a single `.csv` file and returns its
/// decoded text contents, or null if the user cancelled or the file had no
/// readable bytes.
Future<String?> pickCsvFileContents() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return utf8.decode(bytes, allowMalformed: true);
}
