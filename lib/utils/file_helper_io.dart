import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

Future<String?> saveTextFileImpl(String content, String fileName) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save project',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (path != null) {
    final full = path.endsWith('.json') ? path : '$path.json';
    await File(full).writeAsString(content);
    return full;
  }
  return null;
}

Future<String?> loadTextFileImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  final path = result?.files.single.path;
  if (path != null) return File(path).readAsString();
  return null;
}

Future<Uint8List?> pickImageBytesImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null) return null;
  final f = result.files.single;
  if (f.bytes != null) return f.bytes;
  if (f.path != null) return File(f.path!).readAsBytes();
  return null;
}

Future<String?> pickVideoSavePathImpl(String fileName) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Export video',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['mp4'],
  );
  if (path == null) return null;
  return path.endsWith('.mp4') ? path : '$path.mp4';
}

Future<void> revealInFinderImpl(String path) async {
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', path]);
  }
}
