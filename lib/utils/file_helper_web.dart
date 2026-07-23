import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

/// Saves [content] by triggering a browser download (there is no writable
/// filesystem on the web). Returns the file name so the caller can confirm.
Future<String?> saveTextFileImpl(String content, String fileName) async {
  final name = fileName.endsWith('.json') ? fileName : '$fileName.json';
  final parts = <JSAny>[content.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = name;
  anchor.click();
  web.URL.revokeObjectURL(url);
  return name;
}

/// Loads a `.json` project via the browser file picker (bytes come back inline
/// on the web — there is no path to read from).
Future<String?> loadTextFileImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
    withData: true,
  );
  final bytes = result?.files.single.bytes;
  if (bytes == null) return null;
  return utf8.decode(bytes);
}

Future<Uint8List?> pickImageBytesImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  return result?.files.single.bytes;
}

/// Video export is native-only; the web build nudges users to the macOS app,
/// so this is never reached on the web.
Future<String?> pickVideoSavePathImpl(String fileName) async => null;

/// No Finder on the web.
Future<void> revealInFinderImpl(String path) async {}

/// Opens [url] in a new browser tab.
Future<void> openExternalImpl(String url) async {
  web.window.open(url, '_blank');
}
