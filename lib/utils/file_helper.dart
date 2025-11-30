import 'file_helper_stub.dart'
    if (dart.library.html) 'file_helper_web.dart'
    if (dart.library.io) 'file_helper_io.dart';

Future<void> saveProject(String content, String fileName) => saveProjectImpl(content, fileName);
Future<String?> loadProject() => loadProjectImpl();
