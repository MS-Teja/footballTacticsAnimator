import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footballtacticsanimator/models.dart';
import 'package:footballtacticsanimator/controller.dart';

class _V implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  group('Highlight zone keyframe animation', () {
    test('a zone added in the next keyframe grows/fades in (reveal 0 -> 1)', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.home);
      c.addKeyframe(null); // KF0: no zone
      c.addHighlight(const Rect.fromLTWH(30, 20, 10, 8), oval: true);
      c.players.first.position += const Offset(15, 0);
      c.addKeyframe(null); // KF1: zone present

      final start = c.sampleAt(0.0).state.highlights;
      expect(start.single.reveal, 0.0); // not yet revealed at the segment start
      final mid = c.sampleAt(0.5).state.highlights.single.reveal;
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0));
      expect(c.sampleAt(1.0).state.highlights.single.reveal, closeTo(1.0, 0.02));
      c.dispose();
    });

    test('a zone removed in the next keyframe fades out and is gone (not stuck)', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.home);
      c.addHighlight(const Rect.fromLTWH(30, 20, 10, 8), oval: true);
      c.addKeyframe(null); // KF0: zone present
      c.highlights.clear(); // remove it
      c.players.first.position += const Offset(15, 0);
      c.addKeyframe(null); // KF1: no zone

      // Mid-transition it is still shown, fading out...
      final mid = c.sampleAt(0.5).state.highlights;
      expect(mid.single.reveal, greaterThan(0.0));
      expect(mid.single.reveal, lessThan(1.0));
      // ...and by the end it has fully faded (reveal 0), so nothing lingers.
      final end = c.sampleAt(1.0).state.highlights;
      expect(end.isEmpty || end.single.reveal <= 0.02, isTrue);
      c.dispose();
    });

    test('a zone kept across both keyframes stays fully shown (no flicker)', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.home);
      c.addHighlight(const Rect.fromLTWH(30, 20, 10, 8), oval: true);
      c.addKeyframe(null); // KF0: zone present
      c.players.first.position += const Offset(15, 0);
      c.addKeyframe(null); // KF1: same zone still present (id preserved)

      for (final t in [0.0, 0.5, 1.0]) {
        expect(c.sampleAt(t).state.highlights.single.reveal, 1.0, reason: 't=$t');
      }
      c.dispose();
    });

    test('reveal is transient — not serialized (always 1.0 after a round-trip)', () {
      final h = Highlight(rect: const Rect.fromLTWH(1, 2, 3, 4), reveal: 0.3);
      expect(Highlight.fromJson(h.toJson()).reveal, 1.0);
    });
  });
}
