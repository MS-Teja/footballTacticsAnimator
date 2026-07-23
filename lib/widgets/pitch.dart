import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models.dart';

/// Maps between pitch metres (l along length 0..105, w across 0..68) and screen
/// pixels for a given canvas size, orientation and full/half layout.
class PitchGeometry {
  final Size canvas;
  final BoardOrientation orientation;
  final BoardLayout layout;

  late final double _lMin;
  late final double _visLen;
  late final Rect rect; // where the pitch is drawn, in screen px
  late final double pxPerMetre;

  PitchGeometry({required this.canvas, required this.orientation, required this.layout}) {
    _lMin = layout == BoardLayout.full ? 0.0 : kPitchLength / 2;
    _visLen = kPitchLength - _lMin;

    final horizontal = orientation == BoardOrientation.horizontal;
    final aspect = horizontal ? _visLen / kPitchWidth : kPitchWidth / _visLen;

    final availW = canvas.width * 0.95;
    final availH = canvas.height * 0.95;
    double w, h;
    if (aspect > availW / availH) {
      w = availW;
      h = w / aspect;
    } else {
      h = availH;
      w = h * aspect;
    }
    final left = (canvas.width - w) / 2;
    final top = (canvas.height - h) / 2;
    rect = Rect.fromLTWH(left, top, w, h);
    pxPerMetre = horizontal ? w / _visLen : h / _visLen;
  }

  /// Metres (l, w) -> screen pixels.
  Offset toScreen(Offset m) {
    final ln = m.dx - _lMin;
    if (orientation == BoardOrientation.horizontal) {
      return Offset(rect.left + ln * pxPerMetre, rect.top + m.dy * pxPerMetre);
    }
    // Vertical: length runs bottom->top (attacking upward).
    return Offset(rect.left + m.dy * pxPerMetre, rect.bottom - ln * pxPerMetre);
  }

  /// Screen pixels -> metres (l, w).
  Offset toMetres(Offset s) {
    if (orientation == BoardOrientation.horizontal) {
      return Offset(_lMin + (s.dx - rect.left) / pxPerMetre, (s.dy - rect.top) / pxPerMetre);
    }
    return Offset(_lMin + (rect.bottom - s.dy) / pxPerMetre, (s.dx - rect.left) / pxPerMetre);
  }

  double metres(double m) => m * pxPerMetre;
}

/// Draws a Broadcast Green pitch (grass, mow stripes, white markings) that
/// adapts to orientation and full/half layout.
class PitchPainter extends CustomPainter {
  final BoardOrientation orientation;
  final BoardLayout layout;

  PitchPainter({required this.orientation, required this.layout});

  static const Color grass = Color(0xFF1F8A4C);
  static const Color grassDark = Color(0xFF1C7E46);
  static const Color line = Color(0xFFF3F7F4);

  @override
  void paint(Canvas canvas, Size size) {
    final geo = PitchGeometry(canvas: size, orientation: orientation, layout: layout);
    final rect = geo.rect;

    // Surrounding surface. NOTE: must be a bounded drawRect, NOT drawColor —
    // drawColor floods the entire layer (the whole window), which on macOS
    // erased the app bar / tool rail that painted before the board.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0D0F10));

    // Grass base.
    final grassRRect = RRect.fromRectAndRadius(rect.inflate(geo.metres(2.5)), const Radius.circular(6));
    canvas.drawRRect(grassRRect, Paint()..color = grass);

    // Mow stripes along the length.
    const bands = 12;
    for (var i = 0; i < bands; i++) {
      if (i.isEven) continue;
      final l0 = geo.toScreen(Offset(_lStart(geo) + i / bands * _len(geo), 0));
      final l1 = geo.toScreen(Offset(_lStart(geo) + (i + 1) / bands * _len(geo), kPitchWidth));
      final band = Rect.fromPoints(l0, l1);
      canvas.drawRect(band, Paint()..color = grassDark);
    }

    // Clip everything else to the pitch.
    canvas.save();
    canvas.clipRect(rect);

    final lw = math.max(2.0, geo.metres(0.14));
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = lw
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = line;

    // Boundary.
    canvas.drawRect(
      Rect.fromPoints(geo.toScreen(Offset(_lStart(geo), 0)),
          geo.toScreen(const Offset(kPitchLength, kPitchWidth))),
      stroke,
    );

    // Halfway line + centre circle + spot.
    if (layout == BoardLayout.full) {
      canvas.drawLine(geo.toScreen(const Offset(kPitchLength / 2, 0)),
          geo.toScreen(const Offset(kPitchLength / 2, kPitchWidth)), stroke);
    }
    canvas.drawCircle(geo.toScreen(const Offset(kPitchLength / 2, kPitchWidth / 2)),
        geo.metres(9.15), stroke);
    canvas.drawCircle(geo.toScreen(const Offset(kPitchLength / 2, kPitchWidth / 2)),
        geo.metres(0.4), fill);

    // Goal ends.
    _drawEnd(canvas, geo, stroke, fill, atZero: true, visible: layout == BoardLayout.full);
    _drawEnd(canvas, geo, stroke, fill, atZero: false, visible: true);

    // Corner arcs (drawn as full circles, clipped to the pitch = quarter arcs).
    final corners = layout == BoardLayout.full
        ? const [Offset(0, 0), Offset(0, kPitchWidth), Offset(kPitchLength, 0), Offset(kPitchLength, kPitchWidth)]
        : const [Offset(kPitchLength, 0), Offset(kPitchLength, kPitchWidth)];
    for (final c in corners) {
      canvas.drawCircle(geo.toScreen(c), geo.metres(1.0), stroke);
    }

    canvas.restore();
  }

  double _lStart(PitchGeometry g) => layout == BoardLayout.full ? 0.0 : kPitchLength / 2;
  double _len(PitchGeometry g) => kPitchLength - _lStart(g);

  void _drawEnd(Canvas canvas, PitchGeometry geo, Paint stroke, Paint fill,
      {required bool atZero, required bool visible}) {
    if (!visible) return;

    // Penalty area (16.5m deep, 40.32m wide), goal area (5.5m, 18.32m), spot 11m.
    final penL0 = atZero ? 0.0 : kPitchLength - 16.5;
    final penL1 = atZero ? 16.5 : kPitchLength;
    final goalL0 = atZero ? 0.0 : kPitchLength - 5.5;
    final goalL1 = atZero ? 5.5 : kPitchLength;
    final spotL = atZero ? 11.0 : kPitchLength - 11.0;

    canvas.drawRect(
      Rect.fromPoints(geo.toScreen(Offset(penL0, 13.84)), geo.toScreen(Offset(penL1, 54.16))),
      stroke,
    );
    canvas.drawRect(
      Rect.fromPoints(geo.toScreen(Offset(goalL0, 24.84)), geo.toScreen(Offset(goalL1, 43.16))),
      stroke,
    );
    canvas.drawCircle(geo.toScreen(Offset(spotL, kPitchWidth / 2)), geo.metres(0.4), fill);

    // Penalty arc: circle around the spot, clipped to outside the box.
    canvas.save();
    final boxEdge = atZero ? 16.5 : kPitchLength - 16.5;
    final Rect outside;
    if (atZero) {
      outside = Rect.fromPoints(
          geo.toScreen(Offset(boxEdge, 0)), geo.toScreen(const Offset(kPitchLength, kPitchWidth)));
    } else {
      outside = Rect.fromPoints(
          geo.toScreen(Offset(_lStart(geo), 0)), geo.toScreen(Offset(boxEdge, kPitchWidth)));
    }
    canvas.clipRect(outside.intersect(geo.rect));
    canvas.drawCircle(geo.toScreen(Offset(spotL, kPitchWidth / 2)), geo.metres(9.15), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PitchPainter old) =>
      old.orientation != orientation || old.layout != layout;
}
