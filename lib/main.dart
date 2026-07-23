import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart';

import 'models.dart';
import 'controller.dart';
import 'theme.dart';
import 'widgets/tactics_board.dart';
import 'widgets/chrome.dart';
import 'widgets/inspector.dart';
import 'widgets/timeline.dart';
import 'export/board_renderer.dart';
import 'export/video_exporter.dart';
import 'utils/file_helper.dart';

/// Where web users are sent to get the full-featured desktop build.
const String kMacAppUrl = 'https://github.com/MS-Teja/footballTacticsAnimator/releases/latest';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TacticsApp());
}

class TacticsApp extends StatelessWidget {
  const TacticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tactics Animator',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final TacticsController c;

  // Board view transform (zoom/pan for precise placement).
  double _zoom = 1.0;
  Offset _pan = Offset.zero;

  void _zoomBy(double f) => setState(() {
        _zoom = (_zoom * f).clamp(1.0, 4.0);
        if (_zoom == 1.0) _pan = Offset.zero;
      });
  void _resetView() => setState(() {
        _zoom = 1.0;
        _pan = Offset.zero;
      });
  void _panBy(Offset d) {
    if (_zoom <= 1.0) return;
    setState(() {
      final max = 500 * (_zoom - 1);
      _pan = Offset((_pan.dx + d.dx).clamp(-max, max), (_pan.dy + d.dy).clamp(-max, max));
    });
  }

  @override
  void initState() {
    super.initState();
    c = TacticsController(vsync: this);
    c.addListener(_changed);
    // Restore the last session (if any) and arm autosave.
    c.initPersistence();
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    c.removeListener(_changed);
    c.dispose();
    super.dispose();
  }

  // ---- Frame capture (pure canvas — no widget tree) -----------------------
  Future<ui.Image> _renderImage(BoardState state, int width, int height,
      {double reveal = 1.0, double flowPhase = 0.0}) {
    return BoardRenderer.render(
      state: state,
      orientation: c.orientation,
      layout: c.layout,
      showNumbers: c.showNumbers,
      width: width,
      height: height,
      reveal: reveal,
      flowPhase: flowPhase,
      trails: c.showTrails,
      showNames: c.showNames,
    );
  }

  Future<Uint8List?> _capturePng(BoardState state) async {
    try {
      final image = await _renderImage(state, 384, 216);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('thumbnail failed: $e');
      return null;
    }
  }

  // ---- Keyframes ----------------------------------------------------------
  Future<void> _addKeyframe() async {
    final thumb = await _capturePng(c.displayState);
    c.addKeyframe(thumb);
    _toast('Keyframe ${c.keyframes.length} captured');
  }

  Future<void> _updateKeyframeAt(int i) async {
    if (i < 0 || i >= c.keyframes.length) return;
    final thumb = await _capturePng(c.displayState);
    c.updateKeyframe(i, thumb);
    _toast('Keyframe ${i + 1} updated');
  }

  // ---- Save / Load --------------------------------------------------------
  Future<void> _save() async {
    final safe = c.projectName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    final path = await saveTextFile(jsonEncode(c.toProjectJson()), '${safe.isEmpty ? 'tactics_project' : safe}.json');
    if (path != null) _toast('Saved');
  }

  Future<void> _load() async {
    final str = await loadTextFile();
    if (str == null) return;
    try {
      c.loadProjectJson(jsonDecode(str) as Map<String, dynamic>);
      _toast('Loaded');
    } catch (e) {
      _toast('Could not load project');
      debugPrint('load error: $e');
    }
  }

  // ---- Video export -------------------------------------------------------
  Future<void> _exportVideo() async {
    // Native H.264 encoding (AVFoundation) can't run in the browser, so on the
    // web — and any non-macOS build — we point users to the desktop app.
    if (!VideoExporter.isSupported) {
      _showGetMacApp();
      return;
    }
    if (c.keyframes.length < 2) return;
    final settings = await showDialog<_ExportSettings>(context: context, builder: (_) => const _ExportDialog());
    if (settings == null) return;
    final path = await pickVideoSavePath('${c.projectName}.mp4');
    if (path == null) return;

    final width = settings.width;
    final height = (settings.width * 9 / 16).round();
    final fps = settings.fps;
    final bitrate = (width * height * fps * settings.quality).round().clamp(2000000, 80000000);
    final frameCount = (c.totalDuration * fps).round().clamp(2, 36000);

    final progress = ValueNotifier<double>(0);
    var cancelled = false;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ProgressDialog(progress: progress, onCancel: () {
        cancelled = true;
        Navigator.of(ctx).pop();
      }),
    );

    final exporter = VideoExporter();
    try {
      await exporter.start(path: path, width: width, height: height, fps: fps, bitrate: bitrate);
      for (var i = 0; i < frameCount; i++) {
        if (cancelled) break;
        final t = frameCount == 1 ? 0.0 : i / (frameCount - 1);
        final sample = c.sampleAt(t);
        final flowPhase = (t * c.totalDuration) / kArrowFlowPeriod; // matches the board's flow period
        final image = await _renderImage(sample.state, width, height,
            reveal: sample.progress, flowPhase: flowPhase);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        if (data != null) await exporter.addFrame(data.buffer.asUint8List());
        progress.value = (i + 1) / frameCount;
      }
      cancelled ? await exporter.cancel() : await exporter.finish();
    } catch (e) {
      cancelled = true;
      debugPrint('export error: $e');
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    cancelled ? _toast('Export cancelled') : _showExportComplete(path);
  }

  /// Shown when a browser (or non-macOS) user asks for something the web build
  /// can't do — currently MP4 export. Nudges them to the full desktop app.
  void _showGetMacApp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel2,
        icon: const Icon(Icons.desktop_mac_outlined, color: AppColors.accent, size: 40),
        title: const Text('Get the macOS app'),
        content: const SizedBox(
          width: 360,
          child: Text(
            'Video export renders a native H.264 MP4, which the browser can’t do. '
            'Everything else — building plays, keyframes, animation and playback — '
            'works right here. For MP4 export, download the free macOS app.',
            style: TextStyle(color: AppColors.tx2, height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not now')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: const Color(0xFF08130B)),
            icon: const Icon(Icons.download),
            label: const Text('Download for macOS'),
            onPressed: () {
              openExternal(kMacAppUrl);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showExportComplete(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel2,
        icon: const Icon(Icons.check_circle, color: AppColors.accent, size: 40),
        title: const Text('Video exported'),
        content: Text('Saved to:\n$path', style: const TextStyle(color: AppColors.tx2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: const Color(0xFF08130B)),
            icon: const Icon(Icons.folder_open),
            label: const Text('Reveal in Finder'),
            onPressed: () {
              VideoExporter().reveal(path);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ---- Misc ---------------------------------------------------------------
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        width: 260,
        backgroundColor: AppColors.elev,
        duration: const Duration(seconds: 2),
      ));
  }

  bool get _isEditingText => FocusManager.instance.primaryFocus?.context?.widget is EditableText;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Accept Ctrl as well as ⌘ so the shortcuts also work for web users on
    // Windows/Linux.
    final meta = HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (meta && event.logicalKey == LogicalKeyboardKey.keyZ) {
      shift ? c.redo() : c.undo();
      return KeyEventResult.handled;
    }
    if (meta && event.logicalKey == LogicalKeyboardKey.keyS) {
      _save();
      return KeyEventResult.handled;
    }
    if (_isEditingText) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (meta) {
      if (key == LogicalKeyboardKey.keyD) {
        c.duplicateSelection();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyC) {
        c.copySelection();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyV) {
        c.paste();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add) {
        _zoomBy(1.2);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.minus) {
        _zoomBy(1 / 1.2);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit0) {
        _resetView();
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.space) {
      if (c.keyframes.length >= 2) c.isPlaying ? c.pause() : c.play();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      c.removeSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      c.selectMode();
      c.clearSelection();
      return KeyEventResult.handled;
    }
    final nudge = _nudgeDelta(key, HardwareKeyboard.instance.isShiftPressed);
    if (nudge != null && c.nudgeSelection(nudge)) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  /// Arrow-key nudge in metres, mapped so it matches on-screen direction for the
  /// current orientation.
  Offset? _nudgeDelta(LogicalKeyboardKey key, bool shift) {
    final s = shift ? 2.0 : 0.5;
    final horiz = c.orientation == BoardOrientation.horizontal;
    if (key == LogicalKeyboardKey.arrowLeft) return horiz ? Offset(-s, 0) : Offset(0, -s);
    if (key == LogicalKeyboardKey.arrowRight) return horiz ? Offset(s, 0) : Offset(0, s);
    if (key == LogicalKeyboardKey.arrowUp) return horiz ? Offset(0, -s) : Offset(s, 0);
    if (key == LogicalKeyboardKey.arrowDown) return horiz ? Offset(0, s) : Offset(-s, 0);
    return null;
  }

  bool get _boardEmpty => c.players.isEmpty && c.ball == null && c.keyframes.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TopBar(c: c, onSave: _save, onLoad: _load, onExport: _exportVideo),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ToolRail(c: c),
                  Expanded(
                    child: Listener(
                      onPointerSignal: (s) {
                        if (s is PointerScrollEvent) _panBy(-s.scrollDelta);
                      },
                      child: Container(
                        color: AppColors.stage,
                        padding: const EdgeInsets.all(20),
                        child: Stack(
                          children: [
                            Center(
                              child: Transform(
                                alignment: Alignment.center,
                                // Column-major scale (_zoom) + translate (_pan).
                                transform: Matrix4(
                                  _zoom, 0, 0, 0,
                                  0, _zoom, 0, 0,
                                  0, 0, 1, 0,
                                  _pan.dx, _pan.dy, 0, 1,
                                ),
                                transformHitTests: true,
                                child: TacticsBoard(controller: c),
                              ),
                            ),
                            if (_boardEmpty) const Positioned.fill(child: _EmptyHint()),
                            Positioned(top: 8, right: 8, child: StageControls(c: c)),
                            if (c.hasPreview)
                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Center(child: _PreviewChip(c: c)),
                              ),
                            if (_zoom > 1.01)
                              Positioned(bottom: 12, left: 12, child: _ZoomChip(zoom: _zoom, onReset: _resetView)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  InspectorPanel(c: c),
                ],
              ),
            ),
            TimelinePanel(c: c, onAddKeyframe: _addKeyframe, onUpdateKeyframe: _updateKeyframeAt),
          ],
        ),
      ),
    );
  }
}

/// Shown over the stage while a scrubbed/played frame is being previewed, so
/// the (non-editable) board state is never a mystery. Click to return to edit.
class _PreviewChip extends StatelessWidget {
  final TacticsController c;
  const _PreviewChip({required this.c});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: c.stopAndReturnToEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.panel.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.isPlaying ? Icons.play_arrow : Icons.visibility_outlined, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(c.isPlaying ? 'Playing…' : 'Preview — click pitch to edit',
                  style: const TextStyle(color: AppColors.tx, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small floating zoom readout + reset, shown only while zoomed in.
class _ZoomChip extends StatelessWidget {
  final double zoom;
  final VoidCallback onReset;
  const _ZoomChip({required this.zoom, required this.onReset});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Scroll to pan · ⌘0 to reset',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onReset,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.panel.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.zoom_in_rounded, size: 15, color: AppColors.tx2),
                const SizedBox(width: 6),
                Text('${(zoom * 100).round()}%',
                    style: const TextStyle(color: AppColors.tx, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.close_rounded, size: 13, color: AppColors.tx3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.panel.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 18, color: AppColors.accent),
              SizedBox(width: 10),
              Flexible(
                child: Text('Add players from the left rail, or apply a formation in Team Setup →',
                    softWrap: true, style: TextStyle(color: AppColors.tx2, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Export dialogs
// ===========================================================================
class _ExportSettings {
  final int width;
  final int fps;
  final double quality; // bits-per-pixel-per-frame factor
  const _ExportSettings(this.width, this.fps, this.quality);
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog();
  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  int _width = 1920;
  int _fps = 30;
  double _quality = 0.20; // High

  String _estimate() {
    final height = (_width * 9 / 16).round();
    final mbps = (_width * height * _fps * _quality) / 1000000;
    return '$_width×$height · ~${mbps.toStringAsFixed(0)} Mbps (H.264)';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel2,
      title: const Text('Export settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resolution (16:9)', style: TextStyle(color: AppColors.tx2)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1280, label: Text('720p')),
              ButtonSegment(value: 1920, label: Text('1080p')),
              ButtonSegment(value: 2560, label: Text('1440p')),
            ],
            selected: {_width},
            onSelectionChanged: (s) => setState(() => _width = s.first),
          ),
          const SizedBox(height: 16),
          const Text('Frame rate', style: TextStyle(color: AppColors.tx2)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 24, label: Text('24')),
              ButtonSegment(value: 30, label: Text('30')),
              ButtonSegment(value: 60, label: Text('60')),
            ],
            selected: {_fps},
            onSelectionChanged: (s) => setState(() => _fps = s.first),
          ),
          const SizedBox(height: 16),
          const Text('Quality', style: TextStyle(color: AppColors.tx2)),
          const SizedBox(height: 8),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 0.10, label: Text('Standard')),
              ButtonSegment(value: 0.20, label: Text('High')),
              ButtonSegment(value: 0.36, label: Text('Max')),
            ],
            selected: {_quality},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _quality = s.first),
          ),
          const SizedBox(height: 8),
          Text(_estimate(), style: const TextStyle(color: AppColors.tx3, fontSize: 11.5)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: const Color(0xFF08130B)),
          onPressed: () => Navigator.pop(context, _ExportSettings(_width, _fps, _quality)),
          child: const Text('Export'),
        ),
      ],
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progress;
  final VoidCallback onCancel;
  const _ProgressDialog({required this.progress, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel2,
      title: const Text('Exporting video…'),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, value, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: AppColors.panel, color: AppColors.accent),
            ),
            const SizedBox(height: 12),
            Text('${(value * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.tx2)),
          ],
        ),
      ),
      actions: [TextButton(onPressed: onCancel, child: const Text('Cancel'))],
    );
  }
}
