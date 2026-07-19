import 'package:cubeclash/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    // Don't hit the network for fonts during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('App boots into the Timer tab with the 4-tab shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CubeClashApp());
    await tester.pumpAndSettle();

    // Timer is the default landing tab.
    expect(find.text('Timer'), findsWidgets);
    expect(find.text('Hold to start'), findsOneWidget);

    // All four bottom-nav destinations render (selected tab shows its filled
    // icon; the rest show their outlined icons).
    expect(find.byIcon(Icons.timer), findsOneWidget);
    expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
