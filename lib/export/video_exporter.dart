import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin Dart wrapper over the native macOS AVFoundation H.264 encoder.
///
/// Usage: [start] once, [addFrame] for each RGBA frame in order, then [finish].
/// Frames are raw RGBA8888 (width*height*4 bytes) as produced by
/// `ui.Image.toByteData(format: ImageByteFormat.rawRgba)`.
class VideoExporter {
  static const MethodChannel _channel = MethodChannel('tactics/video_exporter');

  /// Whether native encoding is available on this platform.
  static bool get isSupported => defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> start({
    required String path,
    required int width,
    required int height,
    required int fps,
    required int bitrate,
  }) async {
    await _channel.invokeMethod('start', {
      'path': path,
      'width': width,
      'height': height,
      'fps': fps,
      'bitrate': bitrate,
    });
  }

  Future<void> addFrame(Uint8List rgba) async {
    await _channel.invokeMethod('addFrame', {'rgba': rgba});
  }

  Future<void> finish() async {
    await _channel.invokeMethod('finish');
  }

  Future<void> cancel() async {
    await _channel.invokeMethod('cancel');
  }

  /// Reveal a saved file in Finder (sandbox-safe via NSWorkspace).
  Future<void> reveal(String path) async {
    await _channel.invokeMethod('reveal', {'path': path});
  }
}
