import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Autosave lives in the app's support directory. Under the macOS sandbox this
/// resolves to the app container, which is writable and persists across launches.
Future<File> _autosaveFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}${Platform.pathSeparator}autosave.json');
}

Future<void> writePersistedImpl(String content) async {
  final f = await _autosaveFile();
  await f.writeAsString(content, flush: true);
}

Future<String?> readPersistedImpl() async {
  try {
    final f = await _autosaveFile();
    if (await f.exists()) return await f.readAsString();
  } catch (_) {}
  return null;
}
