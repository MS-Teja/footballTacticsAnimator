import 'dart:html' as html;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

Future<void> saveProjectImpl(String content, String fileName) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
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
