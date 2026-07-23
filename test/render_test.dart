import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footballtacticsanimator/models.dart';
import 'package:footballtacticsanimator/export/board_renderer.dart';

void main() {
  // Uses the synchronous recorder — no asset decode, no engine rasterizer —
  // so it runs fast and can never hang in headless mode.
  test('BoardRenderer.recordPicture records without a widget tree or rasterizer', () {
    final state = BoardState(
      players: [
        Player(name: '9', position: const Offset(52, 34), color: Colors.red, color2: Colors.white, team: Team.home),
        Player(name: '7', position: const Offset(70, 20), color: Colors.blue, team: Team.away),
      ],
      ball: Ball(position: const Offset(55, 34)),
      arrows: [Arrow(start: const Offset(40, 40), end: const Offset(65, 25))],
      highlights: [Highlight(rect: const Rect.fromLTWH(60, 10, 20, 20), isOval: true)],
    );

    // Ball omitted (null) → exercises the vector-fallback path too.
    final picture = BoardRenderer.recordPicture(
      state: state,
      orientation: BoardOrientation.horizontal,
      layout: BoardLayout.full,
      showNumbers: true,
      width: 640,
    );
    expect(picture, isNotNull);
    picture.dispose();

    final vertical = BoardRenderer.recordPicture(
      state: state,
      orientation: BoardOrientation.vertical,
      layout: BoardLayout.half,
      showNumbers: false,
      width: 384,
    );
    expect(vertical, isNotNull);
    vertical.dispose();
  });
}
