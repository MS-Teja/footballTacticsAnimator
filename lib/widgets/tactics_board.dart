import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models.dart';
import '../controller.dart';
import 'pitch.dart';

const Size _kCanvas = Size(kBoardWidth, kBoardHeight);

/// The interactive board. Renders the procedural pitch, players, ball and
/// drawings, and handles dragging, drawing tools and selection.
class TacticsBoard extends StatefulWidget {
  final TacticsController controller;
  const TacticsBoard({super.key, required this.controller});

  @override
  State<TacticsBoard> createState() => _TacticsBoardState();
}

class _TacticsBoardState extends State<TacticsBoard> with SingleTickerProviderStateMixin {
  Offset? _dragStart; // canvas px
  Offset? _dragCurrent;

  // Continuously-repeating clock that gives arrows their "flowing" motion.
  // Only runs while at least one arrow is on the board.
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (kArrowFlowPeriod * 1000).round()),
  )..addListener(() => setState(() {}));

  TacticsController get c => widget.controller;
  bool get _drawing => c.activeTool != Tool.none;

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  void _syncFlow(bool hasArrows) {
    if (hasArrows && !_flow.isAnimating) {
      _flow.repeat();
    } else if (!hasArrows && _flow.isAnimating) {
      _flow.stop();
    }
  }

  PitchGeometry get _geo =>
      PitchGeometry(canvas: _kCanvas, orientation: c.orientation, layout: c.layout);

  void _onPanStart(DragStartDetails d) {
    if (_drawing) {
      setState(() {
        _dragStart = d.localPosition;
        _dragCurrent = d.localPosition;
      });
    } else if (_hitTest(d.localPosition, select: true) == null) {
      c.clearSelection();
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_drawing) setState(() => _dragCurrent = d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_drawing || _dragStart == null || _dragCurrent == null) return;
    final start = _dragStart!;
    final end = _dragCurrent!;
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
    if ((end - start).distance < 14) return;
    final geo = _geo;
    final ms = geo.toMetres(start);
    final me = geo.toMetres(end);
    switch (c.activeTool) {
      case Tool.arrow:
        c.addArrow(ms, me);
      case Tool.arrowCurved:
        c.addCurvedArrow(ms, me);
      case Tool.zone:
        c.addHighlight(Rect.fromPoints(ms, me));
      default:
        break;
    }
  }

  Object? _hitTest(Offset canvasPx, {bool select = false}) {
    final geo = _geo;
    final p = geo.toMetres(canvasPx);
    final tol = 1.4; // metres
    final s = c.displayState;
    for (final h in s.highlights.reversed) {
      final inside = h.isOval ? _inOval(h.rect, p) : h.rect.inflate(tol).contains(p);
      if (inside) {
        if (select) c.selectHighlight(h.id);
        return h;
      }
    }
    for (final a in s.arrows.reversed) {
      if (_nearArrow(a, p, tol)) {
        if (select) c.selectArrow(a.id);
        return a;
      }
    }
    return null;
  }

  static bool _inOval(Rect r, Offset p) {
    if (r.width == 0 || r.height == 0) return false;
    final dx = (p.dx - r.center.dx) / (r.width / 2);
    final dy = (p.dy - r.center.dy) / (r.height / 2);
    return dx * dx + dy * dy <= 1.0;
  }

  static bool _nearArrow(Arrow a, Offset p, double tol) {
    if (a.isCurved && a.controlPoint != null) {
      Offset prev = a.start;
      for (var i = 1; i <= 24; i++) {
        final t = i / 24;
        final pt = Offset(
          (1 - t) * (1 - t) * a.start.dx + 2 * (1 - t) * t * a.controlPoint!.dx + t * t * a.end.dx,
          (1 - t) * (1 - t) * a.start.dy + 2 * (1 - t) * t * a.controlPoint!.dy + t * t * a.end.dy,
        );
        if (_distSeg(p, prev, pt) <= tol) return true;
        prev = pt;
      }
      return false;
    }
    return _distSeg(p, a.start, a.end) <= tol;
  }

  static double _distSeg(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
  }

  @override
  Widget build(BuildContext context) {
    final geo = _geo;
    final s = c.displayState;
    final interactive = !(c.isPlaying || c.hasPreview);

    _syncFlow(s.arrows.isNotEmpty);
    // Arrows always have the flowing motion (flowPhase) so they read as "alive".
    // During playback they additionally draw themselves in (reveal = segment
    // progress); while editing they are shown in full (reveal = 1).
    final reveal = interactive ? 1.0 : c.drawProgress;
    final flowPhase = _flow.value;

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: PitchPainter(orientation: c.orientation, layout: c.layout)),
        CustomPaint(
          painter: DrawingsPainter(
            geo: geo,
            arrows: s.arrows,
            highlights: s.highlights,
            selectedArrowId: c.selectedArrowId,
            selectedHighlightId: c.selectedHighlightId,
            previewStart: _dragStart,
            previewEnd: _dragCurrent,
            tool: c.activeTool,
            reveal: reveal,
            flowPhase: flowPhase,
            curveSign: c.curveSign,
          ),
        ),
        if (c.showTrails)
          CustomPaint(painter: TrailsPainter(geo: geo, players: s.players, ball: s.ball)),
        for (final p in s.players) _positioned(geo, p.position, geo.metres(p.size),
            child: _token(geo, p, interactive)),
        if (s.ball != null)
          _positioned(geo, s.ball!.position, geo.metres(s.ball!.size),
              child: _ballWidget(geo, s.ball!, interactive)),
      ],
    );

    // While previewing a scrubbed/paused frame the board is not editable — a
    // tap anywhere returns to edit mode (mirrors the Stop button) so the board
    // can never get stuck "dead". During active playback we leave it alone.
    final Widget content = interactive
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onTapUp: (d) => _hitTest(d.localPosition, select: true) ?? c.clearSelection(),
            child: stack,
          )
        : (c.hasPreview && !c.isPlaying)
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: c.stopAndReturnToEdit,
                child: stack,
              )
            : stack;

    return FittedBox(
      fit: BoxFit.contain,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: kBoardWidth, height: kBoardHeight, child: content),
    );
  }

  Widget _positioned(PitchGeometry geo, Offset metres, double radiusPx, {required Widget child}) {
    final center = geo.toScreen(metres);
    return Positioned(
      left: center.dx - radiusPx,
      top: center.dy - radiusPx,
      width: radiusPx * 2,
      height: radiusPx * 2,
      child: child,
    );
  }

  Widget _token(PitchGeometry geo, Player p, bool interactive) {
    final r = geo.metres(p.size);
    Widget token = PlayerToken(player: p, radius: r, isSelected: c.selectedPlayerId == p.id,
        showNumber: c.showNumbers);
    if (p.opacity < 0.999) token = Opacity(opacity: p.opacity.clamp(0.0, 1.0), child: token);
    if (!interactive || _drawing) return IgnorePointer(child: token);
    return GestureDetector(
      onTap: () => c.selectPlayer(p.id),
      onPanStart: (_) => c.selectPlayer(p.id),
      onPanUpdate: (d) {
        final newPos = geo.toMetres(geo.toScreen(p.position) + d.delta);
        c.movePlayerTo(p, newPos);
      },
      onPanEnd: (_) => c.endDrag(),
      child: token,
    );
  }

  Widget _ballWidget(PitchGeometry geo, Ball ball, bool interactive) {
    final w = BallWidget(radius: geo.metres(ball.size), isSelected: c.ballSelected);
    if (!interactive || _drawing) return IgnorePointer(child: w);
    return GestureDetector(
      onTap: c.selectBall,
      onPanStart: (_) => c.selectBall(),
      onPanUpdate: (d) => c.moveBallTo(geo.toMetres(geo.toScreen(ball.position) + d.delta)),
      onPanEnd: (_) => c.endDrag(),
      child: w,
    );
  }
}

// ===========================================================================
// Drawings painter (arrows + highlights), works in screen space via geometry.
// ===========================================================================
class DrawingsPainter extends CustomPainter {
  final PitchGeometry geo;
  final List<Arrow> arrows;
  final List<Highlight> highlights;
  final String? selectedArrowId;
  final String? selectedHighlightId;
  final Offset? previewStart; // canvas px
  final Offset? previewEnd;
  final Tool tool;
  final double reveal; // 0..1 progressive draw-in fraction for arrows
  final double flowPhase; // 0..1 repeating clock that animates the dash flow
  final double curveSign; // side new curved arrows bend toward (preview only)

  DrawingsPainter({
    required this.geo,
    required this.arrows,
    required this.highlights,
    required this.tool,
    this.selectedArrowId,
    this.selectedHighlightId,
    this.previewStart,
    this.previewEnd,
    this.reveal = 1.0,
    this.flowPhase = 0.0,
    this.curveSign = 1.0,
  });

  double get _sw => math.max(3.0, geo.metres(0.44));

  @override
  void paint(Canvas canvas, Size size) {
    for (final h in highlights) {
      _highlight(canvas, h, h.id == selectedHighlightId);
    }
    for (final a in arrows) {
      _arrow(canvas, a, a.id == selectedArrowId);
    }

    if (previewStart != null && previewEnd != null) {
      switch (tool) {
        case Tool.arrow:
          _drawArrow(canvas, _buildPath(previewStart!, previewEnd!, null), _sw, Colors.white,
              reveal: 1.0, opacity: 1.0, phase: 0.0, curved: false, preview: true);
        case Tool.arrowCurved:
          // Compute the control point in metres so the preview curve matches
          // exactly what gets created on release.
          final ms = geo.toMetres(previewStart!);
          final me = geo.toMetres(previewEnd!);
          final cp = TacticsController.computeControlPoint(ms, me, curveSign);
          _drawArrow(canvas, _buildPath(geo.toScreen(ms), geo.toScreen(me), geo.toScreen(cp)), _sw,
              Colors.white, reveal: 1.0, opacity: 1.0, phase: 0.0, curved: true, preview: true);
        case Tool.zone:
          final r = Rect.fromPoints(previewStart!, previewEnd!);
          canvas.drawOval(r, Paint()..color = const Color(0x40FFEB3B));
          canvas.drawOval(r, Paint()
            ..color = Colors.white.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
        default:
          break;
      }
    }
  }

  void _highlight(Canvas canvas, Highlight h, bool selected) {
    final r = Rect.fromPoints(geo.toScreen(h.rect.topLeft), geo.toScreen(h.rect.bottomRight));
    final fill = Paint()..color = h.color;
    final border = Paint()
      ..color = selected ? Colors.amber : h.color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 3 : math.max(1.5, geo.metres(0.18));
    if (h.isOval) {
      canvas.drawOval(r, fill);
      canvas.drawOval(r, border);
    } else {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, border);
    }
  }

  void _arrow(Canvas canvas, Arrow a, bool selected) {
    final start = geo.toScreen(a.start);
    final end = geo.toScreen(a.end);
    final cp = a.isCurved && a.controlPoint != null ? geo.toScreen(a.controlPoint!) : null;
    final color = selected ? Colors.amber : a.color;
    // Two animation styles: "draw along" traces the stroke (reveal = length),
    // "fade in" keeps the full shape and fades it in (reveal = opacity). Both run
    // on a faster-than-the-segment clock so the arrow completes its intro early
    // and then just flows — the head is never locked to the moving player.
    final double revealLen, opacity;
    if (a.anim == ArrowAnim.fade) {
      revealLen = 1.0;
      opacity = (reveal / 0.6).clamp(0.0, 1.0);
    } else {
      revealLen = (reveal / kArrowDrawFraction).clamp(0.0, 1.0);
      opacity = 1.0;
    }
    _drawArrow(canvas, _buildPath(start, end, cp), selected ? _sw * 1.2 : _sw, color,
        reveal: revealLen, opacity: opacity, phase: flowPhase, curved: a.isCurved, selected: selected);
  }

  Path _buildPath(Offset s, Offset e, Offset? cp) {
    final p = Path()..moveTo(s.dx, s.dy);
    if (cp != null) {
      p.quadraticBezierTo(cp.dx, cp.dy, e.dx, e.dy);
    } else {
      p.lineTo(e.dx, e.dy);
    }
    return p;
  }

  /// Draws an arrow along [path], progressively revealed to [reveal] and drawn
  /// at [opacity], with a soft glow, continuous flowing motion (driven by
  /// [phase]) and a filled head at the leading edge. A straight arrow
  /// ([curved] == false) is a solid line with bright streaks flowing toward the
  /// head; a curved arrow is a dashed line whose dashes march toward the head.
  void _drawArrow(Canvas canvas, Path path, double width, Color color,
      {required double reveal, required double opacity, required double phase, required bool curved, bool selected = false, bool preview = false}) {
    if (opacity <= 0.01) return;
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    if (total < 2) return;

    final revealLen = (total * reveal.clamp(0.0, 1.0)).clamp(0.0, total);
    if (revealLen < 1) return;

    // Stop the shaft at the base of the head so the line never pokes through the
    // tip; the head itself caps the arrow.
    final headLen = math.max(14.0, width * 3.1);
    final shaftLen = math.max(0.0, revealLen - headLen * 0.82);
    final o = opacity.clamp(0.0, 1.0);
    Color a(Color c, double alpha) => c.withValues(alpha: alpha * o);

    if (!preview) {
      // Soft glow underneath so the line reads on any pitch color.
      canvas.drawPath(metric.extractPath(0, revealLen), Paint()
        ..color = a(color, 0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 2.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.75));
    }

    if (curved) {
      // Fully dashed line; the dashes march toward the head as `phase` advances.
      final dash = width * 1.7, gap = width * 1.5, cycle = dash + gap;
      final line = Paint()
        ..color = a(color, 1.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      _dashes(canvas, metric, shaftLen, dash, cycle, phase, line);
    } else {
      // Solid line with bright streaks flowing along it toward the head.
      canvas.drawPath(metric.extractPath(0, shaftLen), Paint()
        ..color = a(color, 1.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round);
      if (!preview) {
        final dash = width * 1.5, cycle = width * 5.0;
        final streak = Paint()
          ..color = a(Colors.white, selected ? 0.95 : 0.82)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 0.44
          ..strokeCap = StrokeCap.round;
        _dashes(canvas, metric, shaftLen, dash, cycle, phase, streak);
      }
    }

    // Filled arrowhead at the leading edge, oriented along the tangent.
    final tan = metric.getTangentForOffset(revealLen);
    if (tan != null) _head(canvas, tan.position, tan.vector.direction, a(color, 1.0), width, headLen);
  }

  /// Lays evenly-spaced dashes along [metric] up to [limit], shifted by [phase]
  /// (0..1) so the pattern flows toward the head.
  void _dashes(Canvas canvas, ui.PathMetric metric, double limit, double dash, double cycle, double phase, Paint paint) {
    if (limit <= 0) return;
    var d = (phase % 1.0) * cycle - cycle;
    while (d < limit) {
      final a0 = math.max(0.0, d);
      final a1 = math.min(limit, d + dash);
      if (a1 > a0) canvas.drawPath(metric.extractPath(a0, a1), paint);
      d += cycle;
    }
  }

  void _head(Canvas canvas, Offset tip, double angle, Color color, double width, double len) {
    final half = len * 0.5;
    final back = Offset(tip.dx - len * math.cos(angle), tip.dy - len * math.sin(angle));
    final perp = Offset(-math.sin(angle), math.cos(angle));
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(back.dx + perp.dx * half, back.dy + perp.dy * half)
        ..lineTo(back.dx - perp.dx * half, back.dy - perp.dy * half)
        ..close(),
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant DrawingsPainter old) => true;
}

// ===========================================================================
// Motion trails — a fading streak from a mover's segment-start to its current
// position. Shared by the live board and the export renderer.
// ===========================================================================
void drawMotionTrail(Canvas canvas, PitchGeometry geo, Offset fromMetres, Offset toMetres, Color color, double radiusPx) {
  final from = geo.toScreen(fromMetres);
  final to = geo.toScreen(toMetres);
  if ((to - from).distance < 2) return;
  final paint = Paint()
    ..shader = ui.Gradient.linear(from, to, [color.withValues(alpha: 0.0), color.withValues(alpha: 0.42)])
    ..strokeWidth = radiusPx * 0.9
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(from, to, paint);
}

class TrailsPainter extends CustomPainter {
  final PitchGeometry geo;
  final List<Player> players;
  final Ball? ball;
  TrailsPainter({required this.geo, required this.players, required this.ball});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in players) {
      if (p.trailFrom != null) {
        drawMotionTrail(canvas, geo, p.trailFrom!, p.position, p.color, geo.metres(p.size));
      }
    }
    if (ball?.trailFrom != null) {
      drawMotionTrail(canvas, geo, ball!.trailFrom!, ball!.position, Colors.white, geo.metres(ball!.size));
    }
  }

  @override
  bool shouldRepaint(covariant TrailsPainter old) => true;
}

// ===========================================================================
// Player token — numbered disc (with optional secondary color, photo, no-number)
// ===========================================================================
class PlayerToken extends StatelessWidget {
  final Player player;
  final double radius;
  final bool isSelected;
  final bool showNumber;
  const PlayerToken({
    super.key,
    required this.player,
    required this.radius,
    required this.isSelected,
    required this.showNumber,
  });

  @override
  Widget build(BuildContext context) {
    final border = isSelected ? Colors.amber : Colors.black.withValues(alpha: 0.55);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: isSelected ? radius * 0.14 : radius * 0.07),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: radius * 0.4,
              offset: Offset(0, radius * 0.18)),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Container(color: player.color),
            if (player.color2 != null)
              ClipPath(clipper: _HalfClipper(), child: Container(color: player.color2)),
            if (player.imageData != null)
              Image.memory(player.imageData!, fit: BoxFit.cover, gaplessPlayback: true)
            else if (showNumber && player.name.isNotEmpty)
              Center(
                child: FittedBox(
                  child: Padding(
                    padding: EdgeInsets.all(radius * 0.28),
                    child: Text(
                      player.name,
                      style: TextStyle(
                        color: player.textColor,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HalfClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()..addRect(Rect.fromLTWH(0, 0, size.width / 2, size.height));
  @override
  bool shouldReclip(CustomClipper<Path> old) => false;
}

// ===========================================================================
// Ball — flat PNG asset
// ===========================================================================
class BallWidget extends StatelessWidget {
  final double radius;
  final bool isSelected;
  const BallWidget({super.key, required this.radius, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.amber, width: radius * 0.16) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: radius * 0.4,
              offset: Offset(radius * 0.12, radius * 0.22)),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/ball.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Never let the ball be invisible if the asset fails to load.
          errorBuilder: (_, __, ___) => CustomPaint(painter: _SoccerBallPainter()),
        ),
      ),
    );
  }
}

/// Vector soccer ball used as a fallback when the PNG asset is unavailable.
class _SoccerBallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
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
    canvas.drawCircle(c, r - 0.5, Paint()..color = const Color(0xFF15181C)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
