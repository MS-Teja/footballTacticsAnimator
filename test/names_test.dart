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
  group('Player name labels', () {
    test('NameStyle + label survive a JSON round-trip', () {
      final p = Player(
        name: '10',
        label: 'Messi',
        position: const Offset(30, 20),
        color: const Color(0xFFE23B3B),
        team: Team.home,
        nameStyle: NameStyle(
          size: 2.4,
          weight: LabelWeight.bold,
          textColor: const Color(0xFF00FF00),
          bgColor: const Color(0xFF102030),
          pos: LabelPos.right,
          shadow: false,
        ),
      );
      final back = Player.fromJson(p.toJson());
      expect(back.label, 'Messi');
      expect(back.nameStyle.size, 2.4);
      expect(back.nameStyle.weight, LabelWeight.bold);
      expect(back.nameStyle.pos, LabelPos.right);
      expect(back.nameStyle.shadow, false);
      expect(back.nameStyle.bgColor, const Color(0xFF102030));
      expect(back.nameStyle.textColor, const Color(0xFF00FF00));
    });

    test('a null background (no plate) round-trips as null', () {
      final p = Player(name: '9', label: 'Haaland', position: Offset.zero, color: const Color(0xFFFFFFFF), team: Team.home, nameStyle: NameStyle(bgColor: null));
      expect(Player.fromJson(p.toJson()).nameStyle.bgColor, isNull);
    });

    test('legacy players (no label/nameStyle) default sensibly', () {
      final legacy = {
        'id': 'x', 'name': '7', 'l': 10.0, 'w': 20.0,
        'color': {'a': 255, 'r': 1, 'g': 2, 'b': 3},
        'color2': null, 'textColor': {'a': 255, 'r': 255, 'g': 255, 'b': 255},
        'size': 2.6, 'imageData': null, 'team': 0,
      };
      final p = Player.fromJson(legacy);
      expect(p.label, '');
      expect(p.nameStyle.pos, LabelPos.below);
    });

    test('applyNameStyleToAll copies style but not text', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.home);
      c.addPlayer(Team.away);
      final src = c.players.first
        ..label = 'Src'
        ..nameStyle.pos = LabelPos.above
        ..nameStyle.weight = LabelWeight.bold;
      c.players.last.label = 'Other';

      c.applyNameStyleToAll(src);

      expect(c.players.last.nameStyle.pos, LabelPos.above);
      expect(c.players.last.nameStyle.weight, LabelWeight.bold);
      expect(c.players.last.label, 'Other'); // text untouched
      c.dispose();
    });

    test('a label added in the next keyframe animates in (does not vanish)', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.home);
      final p = c.players.first;
      // Keyframe 1: no label.
      p.label = '';
      c.addKeyframe(null);
      // Keyframe 2: add a label and move the player.
      p.label = 'Messi';
      p.position = p.position + const Offset(20, 0);
      c.addKeyframe(null);

      // Mid-transition: the destination label is present and fading in.
      final mid = c.sampleAt(0.5).state.players.first;
      expect(mid.label, 'Messi');
      expect(mid.labelOpacity, greaterThan(0.0));
      expect(mid.labelOpacity, lessThan(1.0));

      // End of the move: label fully visible (previously it never appeared).
      final end = c.sampleAt(1.0).state.players.first;
      expect(end.label, 'Messi');
      expect(end.labelOpacity, closeTo(1.0, 0.05));
      c.dispose();
    });

    test('project JSON round-trips name styling + showNames view flag', () {
      final c = TacticsController(vsync: _V());
      c.addPlayer(Team.home);
      c.players.first
        ..label = 'Keeper'
        ..nameStyle.pos = LabelPos.left;
      c.showNames = false;

      final json = c.toProjectJson();

      final c2 = TacticsController(vsync: _V());
      c2.loadProjectJson(json);
      expect(c2.players.single.label, 'Keeper');
      expect(c2.players.single.nameStyle.pos, LabelPos.left);
      expect(c2.showNames, false);
      c.dispose();
      c2.dispose();
    });
  });
}
