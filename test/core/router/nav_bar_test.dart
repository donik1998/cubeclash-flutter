import 'package:cubeclash/app.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/core/network/auth_interceptor.dart';
import 'package:cubeclash/core/router/scaffold_with_nav_bar.dart';
import 'package:cubeclash/features/profile/domain/repositories/profile_repository.dart';
import 'package:cubeclash/features/timer/domain/usecases/generate_scramble.dart';
import 'dart:math';

import 'package:cubeclash/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';
import '../../support/in_memory_settings_repository.dart';

/// Nav bar behaviour, motion and accessibility.
void main() {
  setUpAll(initTestFonts);

  setUp(() async {
    await configureDependencies();
    sl
      ..unregister<SettingsRepository>()
      ..registerSingleton<SettingsRepository>(InMemorySettingsRepository())
      // Seeded: the shell golden renders a real scramble, and an unseeded
      // scrambler would make the image different on every run.
      ..unregister<GenerateScramble>()
      ..registerSingleton<GenerateScramble>(
        GenerateScramble(random: Random(20260719)),
      );

    final TokenStore tokens = sl<TokenStore>();
    await tokens.restore();
    await tokens.setTokens(access: 'a', refresh: 'r');
  });

  tearDown(resetDependencies);

  /// Boots the whole app, since the nav bar only exists inside the shell.
  Future<void> pumpApp(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 780),
          disableAnimations: disableAnimations,
        ),
        child: const CubeClashApp(),
      ),
    );
    await tester.pump();
  }

  group('navigation', () {
    testWidgets('switches tabs', (WidgetTester tester) async {
      await pumpApp(tester);
      expect(find.text('Hold to start'), findsOneWidget);

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(find.text('My Stats'), findsOneWidget);
      expect(find.text('Hold to start'), findsNothing);
    });

    testWidgets('every tab is reachable', (WidgetTester tester) async {
      await pumpApp(tester);

      for (final String tab in <String>['Race', 'Stats', 'You', 'Timer']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }

      expect(find.text('Hold to start'), findsOneWidget);
    });
  });

  /// Whether *our* motion wrapper is present on a given tab.
  ///
  /// Keyed rather than counted by type: the framework contributes several
  /// Transforms of its own to any InkWell, so a raw count measures nothing.
  bool isAnimating(WidgetTester tester, String tab) => find
      .descendant(
        of: find
            .ancestor(of: find.text(tab), matching: find.byType(InkWell))
            .first,
        matching: find.byKey(navItemMotionKey),
      )
      .evaluate()
      .isNotEmpty;

  group('motion', () {
    testWidgets('the selected icon animates mid-flight and settles',
        (WidgetTester tester) async {
      await pumpApp(tester);
      expect(isAnimating(tester, 'Timer'), isFalse, reason: 'at rest');

      await tester.tap(find.text('Race'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        isAnimating(tester, 'Race'),
        isTrue,
        reason: 'the pop, tilt and bob should be mid-flight here',
      );

      // The spec's ~460 ms budget — back to identity after it.
      await tester.pump(const Duration(milliseconds: 500));
      expect(isAnimating(tester, 'Race'), isFalse);
    });

    testWidgets('reduce-motion skips the icon transforms entirely',
        (WidgetTester tester) async {
      await pumpApp(tester, disableAnimations: true);

      await tester.tap(find.text('Race'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        isAnimating(tester, 'Race'),
        isFalse,
        reason: 'motion-sensitive users asked not to receive the character',
      );

      // Let the race gateway's connect timer drain — an outstanding timer at
      // test teardown fails the test regardless of the assertion above.
      await tester.pumpAndSettle();
    });

    testWidgets('tapping the current tab does not restart the animation',
        (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Timer'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(isAnimating(tester, 'Timer'), isFalse);
    });
  });

  group('accessibility', () {
    testWidgets('every tab is a labelled, selectable button',
        (WidgetTester tester) async {
      await pumpApp(tester);

      final SemanticsHandle handle = tester.ensureSemantics();

      for (final String tab in <String>['Timer', 'Race', 'Stats', 'You']) {
        expect(
          find.bySemanticsLabel(tab),
          findsOneWidget,
          reason: '$tab must be announced by name',
        );
      }

      handle.dispose();
    });

    testWidgets('tab targets clear the 48dp minimum',
        (WidgetTester tester) async {
      await pumpApp(tester);

      for (final String tab in <String>['Timer', 'Race', 'Stats', 'You']) {
        final Size size = tester.getSize(
          find
              .ancestor(
                of: find.text(tab),
                matching: find.byType(InkWell),
              )
              .first,
        );

        expect(
          size.width,
          greaterThanOrEqualTo(48),
          reason: '$tab is too narrow to hit reliably',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(48),
          reason: '$tab is too short to hit reliably',
        );
      }
    });
  });

  group('goldens', () {
    testWidgets('the shell, with the selection pill at rest',
        (WidgetTester tester) async {
      for (final (String suffix, Brightness brightness)
          in <(String, Brightness)>[
        ('light', Brightness.light),
        ('dark', Brightness.dark),
      ]) {
        await tester.binding.setSurfaceSize(const Size(390, 780));
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(390, 780)),
            child: Theme(
              data: brightness == Brightness.dark
                  ? AppTheme.dark()
                  : AppTheme.light(),
              child: const CubeClashApp(),
            ),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byType(CubeClashApp),
          matchesGoldenFile('goldens/nav_shell_$suffix.png'),
        );
      }
      await tester.binding.setSurfaceSize(null);
    });
  });
}
