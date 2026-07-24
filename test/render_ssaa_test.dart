import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footballtacticsanimator/models.dart';
import 'package:footballtacticsanimator/export/board_renderer.dart';

void main() {
  test('supersampled render still outputs the requested size', () async {
    final state = BoardState(
      players: [
        Player(name: '10', label: 'Messi', position: const Offset(30, 20), color: const Color(0xFFE23B3B), team: Team.home),
      ],
      ball: Ball(position: const Offset(52, 34)),
      arrows: const [],
      highlights: [Highlight(rect: const Rect.fromLTWH(20, 20, 12, 8), isOval: true)],
    );

    final img = await BoardRenderer.render(
      state: state,
      orientation: BoardOrientation.horizontal,
      layout: BoardLayout.full,
      showNumbers: true,
      width: 640,
      height: 360,
      superSample: 2, // render 1280x720 internally, downscale to 640x360
    );
    expect(img.width, 640);
    expect(img.height, 360);
    img.dispose();
  });

  test('superSample: 1 is a plain render at the target size', () async {
    final state = BoardState(players: const [], ball: null, arrows: const [], highlights: const []);
    final img = await BoardRenderer.render(
      state: state,
      orientation: BoardOrientation.horizontal,
      layout: BoardLayout.full,
      showNumbers: true,
      width: 320,
      height: 180,
    );
    expect(img.width, 320);
    expect(img.height, 180);
    expect(img.runtimeType.toString(), isNotEmpty); // sanity: a real ui.Image
    expect(img is ui.Image, isTrue);
    img.dispose();
  });
}
