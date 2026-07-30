import 'package:cubeclash/features/profile/domain/entities/profile_summary.dart';
import 'package:cubeclash/features/profile/presentation/widgets/profile_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

/// Goldens for the rewritten You · Profile screen (Figma `47:158` / `47:375`).
///
/// These pump [ProfileContent] — the pure layer-B body — directly with
/// constructed [ProfileSummary] data, so every state (including loading, error
/// and the drop-rule edge cases) is reachable deterministically without a
/// cubit or DI container. Light + dark for each.
void main() {
  setUpAll(initTestFonts);

  const Size phone = Size(390, 780);

  ProfileSummary summary({
    String displayName = 'cuber_98',
    String id = 'me',
    String? countryCode = 'UZ',
    int elo = 1180,
    ProfileRank? rank = const ProfileRank(
      event: '3x3',
      metric: 'single',
      scope: 'global',
      position: 1204,
    ),
    int? bestSingleMs = 8420,
    int totalSolves = 3204,
    double? winRate = 0.68,
    int wins = 217,
    int losses = 102,
    int friendCount = 48,
  }) =>
      ProfileSummary(
        id: id,
        displayName: displayName,
        countryCode: countryCode,
        elo: elo,
        rank: rank,
        bestSingleMs: bestSingleMs,
        bestSingleEvent: '3x3',
        totalSolves: totalSolves,
        winRate: winRate,
        wins: wins,
        losses: losses,
        friendCount: friendCount,
      );

  // Wrap in a Scaffold, as ProfilePage does — a bare body renders text with
  // the "no Material ancestor" yellow underline.
  Widget content({
    ProfileSummary? data,
    bool isLoading = false,
    bool hasError = false,
    String? errorMessage,
  }) =>
      Scaffold(
        body: ProfileContent(
          summary: data,
          isLoading: isLoading,
          hasError: hasError,
          errorMessage: errorMessage,
          onRetry: () {},
          onFriends: () {},
          onShare: () {},
          onSettings: () {},
        ),
      );

  Future<void> goldenFor(
    WidgetTester tester,
    Widget page, {
    required String name,
    bool settle = true,
  }) async {
    for (final (String suffix, Brightness brightness) in <(String, Brightness)>[
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      await tester.binding.setSurfaceSize(phone);
      await tester.pumpWidget(
        harnessPage(page, brightness: brightness, size: phone),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/you_${name}_$suffix.png'),
      );
    }
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('loading', (WidgetTester tester) async {
    await goldenFor(
      tester,
      content(isLoading: true),
      name: 'loading',
      settle: false,
    );
  });

  testWidgets('error', (WidgetTester tester) async {
    await goldenFor(
      tester,
      content(hasError: true, errorMessage: 'Could not load your profile.'),
      name: 'error',
    );
  });

  testWidgets('nominal', (WidgetTester tester) async {
    await goldenFor(tester, content(data: summary()), name: 'nominal');
  });

  testWidgets('no country', (WidgetTester tester) async {
    await goldenFor(
      tester,
      content(data: summary(countryCode: null)),
      name: 'no_country',
    );
  });

  testWidgets('unranked', (WidgetTester tester) async {
    // New user: no rank, no best, no races → subtitle collapses, tiles "—".
    await goldenFor(
      tester,
      content(
        data: summary(
          elo: 1000,
          rank: null,
          bestSingleMs: null,
          totalSolves: 0,
          winRate: null,
          wins: 0,
          losses: 0,
          friendCount: 0,
        ),
      ),
      name: 'unranked',
    );
  });

  testWidgets('long name', (WidgetTester tester) async {
    await goldenFor(
      tester,
      content(
        data: summary(
          displayName: 'the_absolute_longest_cuber_username_ever_recorded',
          rank: const ProfileRank(
            event: '3x3',
            metric: 'single',
            scope: 'global',
            position: 12048,
          ),
          bestSingleMs: 743210, // 12:23.21 — a 12+ minute best
          totalSolves: 128450,
          friendCount: 4820,
        ),
      ),
      name: 'long_name',
    );
  });
}
