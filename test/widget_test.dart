import 'package:cubeclash/app.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/core/network/auth_interceptor.dart';
import 'package:cubeclash/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/in_memory_settings_repository.dart';

/// App-level boot tests: the router's auth guard is what decides the very
/// first screen, so it gets tested here rather than in isolation.
void main() {
  setUpAll(initTestFonts);

  setUp(() async {
    await configureDependencies();
    // shared_preferences has no platform channel under `flutter test`.
    sl
      ..unregister<SettingsRepository>()
      ..registerSingleton<SettingsRepository>(InMemorySettingsRepository());
  });

  tearDown(resetDependencies);

  testWidgets('a signed-out launch lands on the welcome screen',
      (WidgetTester tester) async {
    await sl<TokenStore>().restore(); // nothing stored

    await tester.pumpWidget(const CubeClashApp());
    await tester.pumpAndSettle();

    expect(find.text('CubeClash'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    // No shell, so no nav bar.
    expect(find.byIcon(Icons.timer), findsNothing);
  });

  testWidgets('a signed-in launch lands on the Timer tab with the 4-tab shell',
      (WidgetTester tester) async {
    final TokenStore tokens = sl<TokenStore>();
    await tokens.restore();
    await tokens.setTokens(access: 'a', refresh: 'r');

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

  testWidgets('losing the session mid-run bounces back to auth',
      (WidgetTester tester) async {
    final TokenStore tokens = sl<TokenStore>();
    await tokens.restore();
    await tokens.setTokens(access: 'a', refresh: 'r');

    await tester.pumpWidget(const CubeClashApp());
    await tester.pump();
    expect(find.text('Hold to start'), findsOneWidget);

    // This is what AuthInterceptor does when a refresh fails for good.
    await tokens.clear();
    await tester.pumpAndSettle();

    expect(find.text('Create an account'), findsOneWidget);
  });
}
