import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';
import '../widgets/pitch.dart';
import '../widgets/tactics_board.dart' show DrawingsPainter, drawMotionTrail;

/// Renders a [BoardState] straight to a [ui.Image] via a [ui.PictureRecorder],
/// with NO widget tree involvement. This replaces the fragile offscreen
/// RepaintBoundary approach (which repeatedly broke painting/interaction on
/// macOS). Used for keyframe thumbnails and video frames.
class BoardRenderer {
  static ui.Image? _ball;
  static bool _ballLoadFailed = false;
  static final Map<Uint8List, ui.Image> _photoCache = {};

  /// Loads the flat ball PNG, tolerating a missing/corrupt asset (returns null,
  /// so the caller draws the vector fallback instead of aborting the export).
  static Future<ui.Image?> _ballImage() async {
    if (_ball != null) return _ball;
    if (_ballLoadFailed) return null;
    try {
      final data = await rootBundle.load('assets/ball.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _ball = (await codec.getNextFrame()).image;
      return _ball;
    } catch (_) {
      _ballLoadFailed = true;
      return null;
    }
  }

  static Future<ui.Image?> _photo(Uint8List bytes) async {
    final cached = _photoCache[bytes];
    if (cached != null) return cached;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final img = (await codec.getNextFrame()).image;
      _photoCache[bytes] = img;
      return img;
    } catch (_) {
      return null;
    }
  }

  /// Render [state] to a [width]x[height] (16:9) image. Decodes assets (async),
  /// then hands off to the synchronous [recordPicture] and rasterizes.
  static Future<ui.Image> render({
    required BoardState state,
    required BoardOrientation orientation,
    required BoardLayout layout,
    required bool showNumbers,
    required int width,
    required int height,
    double reveal = 1.0,
    double flowPhase = 0.0,
    bool trails = false,
  }) async {
    final ball = state.ball != null ? await _ballImage() : null;
    final photos = <String, ui.Image>{};
    for (final p in state.players) {
      if (p.imageData != null) {
        final img = await _photo(p.imageData!);
        if (img != null) photos[p.id] = img;
      }
    }

    final picture = recordPicture(
      state: state,
      orientation: orientation,
      layout: layout,
      showNumbers: showNumbers,
      width: width,
      ball: ball,
      photos: photos,
      reveal: reveal,
      flowPhase: flowPhase,
      trails: trails,
    );
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  /// Records the board drawing into a [ui.Picture] — fully synchronous, no image
  /// decode and no rasterizer, so it is safe (and fast) in headless tests.
  /// Pre-decoded [ball] / [photos] are optional; a null ball is drawn as the
  /// vector fallback.
  static ui.Picture recordPicture({
    required BoardState state,
    required BoardOrientation orientation,
    required BoardLayout layout,
    required bool showNumbers,
    required int width,
    ui.Image? ball,
    Map<String, ui.Image> photos = const {},
    double reveal = 1.0,
    double flowPhase = 0.0,
    bool trails = false,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const logical = Size(kBoardWidth, kBoardHeight);
    canvas.scale(width / kBoardWidth);

    PitchPainter(orientation: orientation, layout: layout).paint(canvas, logical);
    final geo = PitchGeometry(canvas: logical, orientation: orientation, layout: layout);
    DrawingsPainter(
      geo: geo,
      arrows: state.arrows,
      highlights: state.highlights,
      tool: Tool.none,
      reveal: reveal,
      flowPhase: flowPhase,
    ).paint(canvas, logical);
    if (trails) {
      for (final p in state.players) {
        if (p.trailFrom != null) {
          drawMotionTrail(canvas, geo, p.trailFrom!, p.position, p.color, geo.metres(p.size));
        }
      }
      if (state.ball?.trailFrom != null) {
        drawMotionTrail(canvas, geo, state.ball!.trailFrom!, state.ball!.position, const Color(0xFFFFFFFF), geo.metres(state.ball!.size));
      }
    }
    for (final p in state.players) {
      _drawPlayer(canvas, geo, p, showNumbers, photos[p.id]);
    }
    if (state.ball != null) _drawBall(canvas, geo, state.ball!, ball);

    return recorder.endRecording();
  }

  static void _drawPlayer(Canvas canvas, PitchGeometry geo, Player p, bool showNumbers, ui.Image? photo) {
    final c = geo.toScreen(p.position);
    final r = geo.metres(p.size);
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));

    // Fade the whole token as one unit when it is appearing/disappearing.
    final faded = p.opacity < 0.999;
    if (faded) {
      canvas.saveLayer(Rect.fromCircle(center: c, radius: r * 1.8),
          Paint()..color = Colors.white.withValues(alpha: p.opacity.clamp(0.0, 1.0)));
    }

    canvas.drawCircle(c.translate(0, r * 0.18), r,
        Paint()..color = Colors.black.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(c, r, Paint()..color = p.color);
    if (p.color2 != null) {
      canvas.save();
      canvas.clipPath(circle);
      canvas.drawRect(Rect.fromLTWH(c.dx - r, c.dy - r, r, 2 * r), Paint()..color = p.color2!);
      canvas.restore();
    }
    if (photo != null) {
      canvas.save();
      canvas.clipPath(circle);
      final dst = Rect.fromCircle(center: c, radius: r);
      canvas.drawImageRect(photo, _coverSrc(photo, dst), dst, Paint());
      canvas.restore();
    } else if (showNumbers && p.name.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: p.name, style: TextStyle(color: p.textColor, fontWeight: FontWeight.w800, fontSize: r * 0.9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    }
    canvas.drawCircle(c, r,
        Paint()..color = Colors.black.withValues(alpha: 0.55)..style = PaintingStyle.stroke..strokeWidth = r * 0.08);

    if (faded) canvas.restore();
  }

  static void _drawBall(Canvas canvas, PitchGeometry geo, Ball b, ui.Image? ball) {
    final c = geo.toScreen(b.position);
    final r = geo.metres(b.size);
    canvas.drawCircle(c.translate(r * 0.12, r * 0.22), r,
        Paint()..color = Colors.black.withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final dst = Rect.fromCircle(center: c, radius: r);
    if (ball != null) {
      canvas.drawImageRect(ball, _coverSrc(ball, dst), dst, Paint());
    } else {
      _drawBallVector(canvas, c, r);
    }
    canvas.restore();
  }

  /// Vector soccer ball, mirroring the widget-side fallback, used when the flat
  /// PNG asset can't be loaded.
  static void _drawBallVector(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    final black = Paint()..color = const Color(0xFF15181C);
    Path pent(Offset ctr, double rad, double rot) {
      final p = Path();
      for (var i = 0; i < 5; i++) {
        final a = rot + i * 72 * math.pi / 180;
        final pt = Offset(ctr.dx + rad * math.cos(a), ctr.dy + rad * math.sin(a));
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    }

    canvas.drawPath(pent(c, r * 0.42, -math.pi / 2), black);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 72 * math.pi / 180;
      canvas.drawPath(pent(Offset(c.dx + r * 0.74 * math.cos(a), c.dy + r * 0.74 * math.sin(a)), r * 0.26, a + math.pi), black);
    }
  }

  static Rect _coverSrc(ui.Image img, Rect dst) {
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final scale = (dst.width / iw > dst.height / ih) ? dst.width / iw : dst.height / ih;
    final w = dst.width / scale, h = dst.height / scale;
    return Rect.fromLTWH((iw - w) / 2, (ih - h) / 2, w, h);
  }
}
