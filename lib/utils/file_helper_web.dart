import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

Future<void> saveProjectImpl(String content, String fileName) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

Future<String?> loadProjectImpl() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );

  if (result != null) {
    final bytes = result.files.single.bytes;
    if (bytes != null) {
      return utf8.decode(bytes);
    }
  }
  return null;
}
