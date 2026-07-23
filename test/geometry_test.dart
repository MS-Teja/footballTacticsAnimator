import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footballtacticsanimator/models.dart';
import 'package:footballtacticsanimator/controller.dart';
import 'package:footballtacticsanimator/widgets/pitch.dart';

class _V implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

const _canvas = Size(kBoardWidth, kBoardHeight);

void main() {
  group('PitchGeometry', () {
    test('horizontal full: centre maps to canvas centre and round-trips', () {
      final g = PitchGeometry(canvas: _canvas, orientation: BoardOrientation.horizontal, layout: BoardLayout.full);
      final centre = g.toScreen(const Offset(kPitchLength / 2, kPitchWidth / 2));
      expect(centre.dx, closeTo(kBoardWidth / 2, 0.5));
      expect(centre.dy, closeTo(kBoardHeight / 2, 0.5));

      // Goal at l=0 is left of centre, l=105 is right.
      expect(g.toScreen(const Offset(0, 34)).dx, lessThan(centre.dx));
      expect(g.toScreen(const Offset(105, 34)).dx, greaterThan(centre.dx));

      // Round trip.
      const p = Offset(30, 20);
      final back = g.toMetres(g.toScreen(p));
      expect(back.dx, closeTo(p.dx, 0.01));
      expect(back.dy, closeTo(p.dy, 0.01));
    });

    test('vertical full: length runs bottom (0) to top (105)', () {
      final g = PitchGeometry(canvas: _canvas, orientation: BoardOrientation.vertical, layout: BoardLayout.full);
      final centre = g.toScreen(const Offset(kPitchLength / 2, kPitchWidth / 2));
      expect(centre.dx, closeTo(kBoardWidth / 2, 0.5));
      expect(g.toScreen(const Offset(105, 34)).dy, lessThan(centre.dy)); // attacking up
      expect(g.toScreen(const Offset(0, 34)).dy, greaterThan(centre.dy));

      const p = Offset(70, 50);
      final back = g.toMetres(g.toScreen(p));
      expect(back.dx, closeTo(p.dx, 0.01));
      expect(back.dy, closeTo(p.dy, 0.01));
    });

    test('half pitch shows the far half only', () {
      final g = PitchGeometry(canvas: _canvas, orientation: BoardOrientation.horizontal, layout: BoardLayout.half);
      // l = 52.5 is the near edge (left), l = 105 the far edge (right).
      final left = g.toScreen(const Offset(52.5, 34));
      final right = g.toScreen(const Offset(105, 34));
      expect(left.dx, lessThan(right.dx));
      expect(right.dx - left.dx, greaterThan(0));
      final back = g.toMetres(g.toScreen(const Offset(80, 40)));
      expect(back.dx, closeTo(80, 0.01));
      expect(back.dy, closeTo(40, 0.01));
    });
  });

  group('Animation interpolation', () {
    test('midpoint of a two-keyframe move is halfway', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.home);
      final p = c.players.first;
      p.position = const Offset(10, 34);
      c.addKeyframe(null); // keyframe 0
      p.position = const Offset(90, 34);
      c.addKeyframe(null); // keyframe 1
      c.setKeyframeEase(1, EaseType.linear); // linear => exact midpoint

      expect(c.keyframes.first.transitionSeconds, 0);
      expect(c.keyframes.length, 2);

      final mid = c.interpolatedStateAt(0.5);
      expect(mid.players.first.position.dx, closeTo(50, 0.5));
      expect(mid.players.first.position.dy, closeTo(34, 0.5));

      final start = c.interpolatedStateAt(0.0);
      expect(start.players.first.position.dx, closeTo(10, 0.5));
      final end = c.interpolatedStateAt(1.0);
      expect(end.players.first.position.dx, closeTo(90, 0.5));

      c.dispose();
    });

    test('hold time extends total duration and pauses on the frame', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.home);
      c.players.first.position = const Offset(20, 34);
      c.addKeyframe(null);
      c.players.first.position = const Offset(80, 34);
      c.addKeyframe(null);
      c.setKeyframeDuration(1, 2.0);
      c.setKeyframeHold(1, 1.0);
      expect(c.totalDuration, closeTo(3.0, 0.001)); // 2s move + 1s hold
      // During the trailing hold (last 1/3) the board sits on the final frame.
      expect(c.sampleAt(0.95).state.players.first.position.dx, closeTo(80, 0.5));
      c.dispose();
    });

    test('sampleAt reports eased segment progress for arrow reveal', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.home);
      c.addKeyframe(null);
      c.players.first.position = const Offset(90, 34);
      c.addKeyframe(null);
      c.setKeyframeEase(1, EaseType.linear);

      final mid = c.sampleAt(0.5);
      expect(mid.segment, 0);
      expect(mid.progress, closeTo(0.5, 0.02));
      expect(c.sampleAt(0.0).progress, closeTo(0.0, 0.02));
      expect(c.sampleAt(1.0).progress, closeTo(1.0, 0.02));

      c.dispose();
    });
  });

  group('Drawing tools', () {
    test('arrow tool adds a movement arrow and returns to select mode', () {
      final c = TacticsController(vsync: _V());
      c.setTool(Tool.arrow);
      expect(c.activeTool, Tool.arrow);
      c.addArrow(const Offset(10, 10), const Offset(50, 30));
      expect(c.arrows.length, 1);
      expect(c.activeTool, Tool.none, reason: 'tool resets after drawing');
      c.dispose();
    });

    test('curved arrow tool adds a curved arrow with a control point', () {
      final c = TacticsController(vsync: _V());
      c.setTool(Tool.arrowCurved);
      c.addCurvedArrow(const Offset(10, 10), const Offset(60, 30));
      expect(c.arrows.length, 1);
      expect(c.arrows.first.isCurved, true);
      expect(c.arrows.first.controlPoint, isNotNull);
      expect(c.activeTool, Tool.none);
      c.dispose();
    });

    test('curved arrows support both directions and flipping', () {
      const s = Offset(10, 34), e = Offset(60, 34);
      final up = TacticsController.computeControlPoint(s, e, 1);
      final down = TacticsController.computeControlPoint(s, e, -1);
      // Opposite sides of the chord.
      expect((up.dy - 34).sign, isNot((down.dy - 34).sign));

      final c = TacticsController(vsync: _V());
      c.addCurvedArrow(s, e);
      final before = TacticsController.curveSideOf(c.arrows.first);
      c.flipArrowCurve(c.arrows.first);
      expect(TacticsController.curveSideOf(c.arrows.first), isNot(before));
      c.dispose();
    });

    test('arrow animation style can be set', () {
      final c = TacticsController(vsync: _V());
      c.addArrow(const Offset(10, 10), const Offset(50, 30));
      expect(c.arrows.first.anim, ArrowAnim.draw);
      c.setArrowAnim(c.arrows.first, ArrowAnim.fade);
      expect(c.arrows.first.anim, ArrowAnim.fade);
      c.dispose();
    });

    test('zone tool adds an oval highlight', () {
      final c = TacticsController(vsync: _V());
      c.setTool(Tool.zone);
      c.addHighlight(const Rect.fromLTWH(20, 20, 12, 8));
      expect(c.highlights.length, 1);
      expect(c.highlights.first.isOval, true);
      c.dispose();
    });
  });

  group('Editor tools', () {
    test('nudge moves the selected player and is undoable', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.home);
      final before = c.selectedPlayer!.position;
      expect(c.nudgeSelection(const Offset(2, 0)), true);
      expect(c.selectedPlayer!.position.dx, closeTo(before.dx + 2, 0.001));
      c.undo();
      expect(c.players.first.position.dx, closeTo(before.dx, 0.001));
      c.dispose();
    });

    test('copy/paste adds an offset duplicate and selects it', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.away);
      final id = c.selectedPlayerId;
      c.copySelection();
      c.paste();
      expect(c.players.length, 2);
      expect(c.selectedPlayerId, isNot(id));
      c.dispose();
    });

    test('duplicate works for arrows', () {
      final c = TacticsController(vsync: _V());
      c.addArrow(const Offset(10, 10), const Offset(40, 20));
      c.selectArrow(c.arrows.first.id);
      c.duplicateSelection();
      expect(c.arrows.length, 2);
      c.dispose();
    });
  });
}
