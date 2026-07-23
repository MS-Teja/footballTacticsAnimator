import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footballtacticsanimator/main.dart';
import 'package:footballtacticsanimator/models.dart';
import 'package:footballtacticsanimator/widgets/tactics_board.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TacticsApp());
    await tester.pump();
  }

  testWidgets('tapping a player selects it', (tester) async {
    await pump(tester);
    final c = tester.widget<TacticsBoard>(find.byType(TacticsBoard)).controller;
    c.addPlayer(Team.home);
    await tester.pump();

    expect(c.selectedPlayer, isNotNull, reason: 'addPlayer selects the new player');

    // A live, tappable token exists on the board.
    expect(find.byType(PlayerToken), findsWidgets);
    c.clearSelection();
    await tester.pump();
    expect(c.selectedPlayer, isNull);

    await tester.tap(find.byType(PlayerToken).first);
    await tester.pump();
    expect(c.selectedPlayer, isNotNull, reason: 'tapping the token selects the player');
    expect(tester.takeException(), isNull);
  });

  testWidgets('add ball creates a visible ball widget', (tester) async {
    await pump(tester);
    final c = tester.widget<TacticsBoard>(find.byType(TacticsBoard)).controller;
    expect(c.ball, isNull);
    c.addBall();
    await tester.pump();
    expect(c.ball, isNotNull);
    expect(find.byType(BallWidget), findsWidgets);
  });

  testWidgets('selecting a keyframe then editing releases the keyframe selection', (tester) async {
    await pump(tester);
    final c = tester.widget<TacticsBoard>(find.byType(TacticsBoard)).controller;
    c.addPlayer(Team.home);
    c.clearSelection();
    await tester.pump();
    // fake two keyframes
    c.addKeyframe(null);
    c.addKeyframe(null);
    c.selectKeyframe(0);
    await tester.pump();
    expect(c.selectedKeyframeIndex, 0);

    // Moving a player (as a drag would) clears the keyframe selection.
    c.selectPlayer(c.players.first.id);
    expect(c.selectedKeyframeIndex, isNull, reason: 'editing releases the keyframe lock');
  });
}
