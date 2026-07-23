import 'package:flutter/foundation.dart';

import 'file_helper_stub.dart'
    if (dart.library.io) 'file_helper_io.dart';

/// Save a text file, returning the chosen path (or null if cancelled).
Future<String?> saveTextFile(String content, String fileName) =>
    saveTextFileImpl(content, fileName);

/// Load a `.json` project file's contents (or null if cancelled).
Future<String?> loadTextFile() => loadTextFileImpl();

/// Pick an image and return its raw bytes (or null).
Future<Uint8List?> pickImageBytes() => pickImageBytesImpl();

/// Ask the user where to save a video, returning the path (or null).
Future<String?> pickVideoSavePath(String fileName) => pickVideoSavePathImpl(fileName);

/// Reveal a file in Finder (macOS only; no-op elsewhere).
Future<void> revealInFinder(String path) => revealInFinderImpl(path);
