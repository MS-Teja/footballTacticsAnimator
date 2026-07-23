import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:footballtacticsanimator/main.dart';

void main() {
  testWidgets('App builds and shows the toolbar', (WidgetTester tester) async {
    // Wide enough for the test's Ahem font (every glyph is a full em, so text
    // is ~40% wider than the real macOS font the app ships with).
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TacticsApp());
    await tester.pump();

    // The Export action should be present in the toolbar.
    expect(find.text('Export MP4'), findsOneWidget);
  });
}
