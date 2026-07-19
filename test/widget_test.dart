import 'package:cubeclash/app.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  setUpAll(initTestFonts);

  setUp(configureDependencies);
  tearDown(resetDependencies);

  testWidgets('App boots into the Timer tab with the 4-tab shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CubeClashApp());
    await tester.pump();

    // Timer is the default landing tab, showing its idle prompt.
    expect(find.text('Timer'), findsWidgets);
    expect(find.text('Hold to start'), findsOneWidget);

    // A scramble is proposed immediately — the user can start solving on the
    // first frame without waiting on anything.
    expect(find.text('SCRAMBLE'), findsOneWidget);

    // All four bottom-nav destinations render (selected tab shows its filled
    // icon; the rest show their outlined icons).
    expect(find.byIcon(Icons.timer), findsOneWidget);
    expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
