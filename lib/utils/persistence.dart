import 'persistence_stub.dart'
    if (dart.library.io) 'persistence_io.dart'
    if (dart.library.js_interop) 'persistence_web.dart';

/// Write the autosave payload to durable local storage (a file in the app's
/// support directory on desktop, localStorage on the web). May throw on the web
/// if the storage quota is exceeded — callers should tolerate that.
Future<void> writePersisted(String content) => writePersistedImpl(content);

/// Read the autosave payload, or null if there is none.
Future<String?> readPersisted() => readPersistedImpl();
