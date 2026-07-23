import 'package:web/web.dart' as web;

const String _key = 'tactics_autosave_v1';

/// Persists to window.localStorage. Throws (QuotaExceededError) if the payload
/// is too large — the controller retries with a lighter payload.
Future<void> writePersistedImpl(String content) async {
  web.window.localStorage.setItem(_key, content);
}

Future<String?> readPersistedImpl() async {
  return web.window.localStorage.getItem(_key);
}
