import 'dart:io';
import 'package:file_picker/file_picker.dart';

Future<void> saveProjectImpl(String content, String fileName) async {
  String? outputFile = await FilePicker.platform.saveFile(
    dialogTitle: 'Please select an output file:',
    fileName: fileName,
  );

  if (outputFile != null) {
    final file = File(outputFile);
    await file.writeAsString(content);
  }
}

Future<String?> loadProjectImpl() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );

  if (result != null && result.files.single.path != null) {
    final file = File(result.files.single.path!);
    return await file.readAsString();
  }
  return null;
}
