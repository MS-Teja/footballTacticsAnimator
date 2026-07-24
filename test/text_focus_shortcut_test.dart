import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the "Backspace deletes the player while I'm typing in
/// the number/name field" bug. The global key handler skips board shortcuts
/// when a text field is focused, using this detection. The old check
/// (`primaryFocus.context.widget is EditableText`) was always false because the
/// focused node's widget is EditableText's *internal* Focus, so shortcuts fired
/// while editing. This verifies the ancestor-walk detection actually trips.
void main() {
  testWidgets('a focused TextField is detected as text editing', (tester) async {
    final node = FocusNode();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: TextField(focusNode: node))),
    ));

    node.requestFocus();
    await tester.pump();

    final ctx = FocusManager.instance.primaryFocus?.context;
    expect(ctx, isNotNull);

    // The old, broken check — the focused widget itself is NOT an EditableText.
    final oldCheck = ctx!.widget is EditableText;
    expect(oldCheck, isFalse, reason: 'focused widget is the internal Focus, not EditableText');

    // The fix — walk up to the enclosing EditableText.
    final newCheck = ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
    expect(newCheck, isTrue, reason: 'editing must be detected so Backspace/Delete are left to the field');

    node.dispose();
  });

  testWidgets('with nothing focused, no text editing is reported', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump();

    final ctx = FocusManager.instance.primaryFocus?.context;
    final editing = ctx != null &&
        (ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null);
    expect(editing, isFalse);
  });
}
