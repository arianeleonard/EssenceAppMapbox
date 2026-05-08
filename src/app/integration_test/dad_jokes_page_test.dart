import 'package:app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test for the Map page.
Future<void> mapPageSmokeTest() async {
  testWidgets('Map page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pump(const Duration(seconds: 1));
    // The map page scaffold should be present.
    expect(find.byType(Scaffold), findsWidgets);
    await tester.pumpAndSettle();
  });
}
