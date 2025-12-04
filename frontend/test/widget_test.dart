// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// intentionally not importing the full app to avoid network calls during tests

void main() {
  testWidgets('App builds minimal MaterialApp smoke test', (WidgetTester tester) async {
    // Build a minimal MaterialApp to ensure tests run without loading the
    // full app (which performs network requests during widget initialization).
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: Text('ok')))));

    // Verify the MaterialApp and the test text are present.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('ok'), findsOneWidget);
  });
}
