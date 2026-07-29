import 'package:cubeclash/core/theme/app_colors.dart';
import 'package:cubeclash/core/widgets/leaderboard_row.dart';
import 'package:cubeclash/features/stats/domain/entities/leaderboard_entry.dart';
import 'package:cubeclash/features/stats/presentation/widgets/leaderboard_gap.dart';
import 'package:cubeclash/features/stats/presentation/widgets/leaderboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

/// Fixed-time formatter so a golden never depends on the WCA precision rules —
/// the row's own tabular figures are asserted separately.
String _fmt(int ms) => (ms / 1000).toStringAsFixed(2);

const List<LeaderboardEntry> _entries = <LeaderboardEntry>[
  LeaderboardEntry(
    userId: 'u1',
    rank: 1,
    displayName: 'kian_r',
    timeMs: 6310,
    countryCode: 'IR',
  ),
  LeaderboardEntry(
    userId: 'u2',
    rank: 2,
    displayName: 'yush_z',
    timeMs: 6480,
    countryCode: 'CN',
  ),
  LeaderboardEntry(
    userId: 'u3',
    rank: 3,
    displayName: 'm.dubois',
    timeMs: 6550,
    countryCode: 'FR',
  ),
  LeaderboardEntry(
    userId: 'u4',
    rank: 4,
    displayName: 's.patel',
    timeMs: 6710,
    countryCode: 'IN',
  ),
  LeaderboardEntry(
    userId: 'u5',
    rank: 5,
    displayName: 'emma_c',
    timeMs: 6830,
    countryCode: 'US',
  ),
];

// Note the display name is a real username, not "You" — the pinned viewer row
// must still render the literal "You" (spec §7), proving the override is a UI
// concern and does not depend on the fake setting displayName='You'.
const LeaderboardEntry _viewer = LeaderboardEntry(
  userId: 'me',
  rank: 1204,
  displayName: 'kian_r',
  timeMs: 8420,
  countryCode: 'UZ',
  isCurrentUser: true,
);

LeaderboardView _view({
  bool isLoading = false,
  bool isLoadingMore = false,
  bool isEmpty = false,
  String? failureMessage,
  Leaderboard? leaderboard = const Leaderboard(entries: _entries),
  LeaderboardEntry? pinnedViewer = _viewer,
  LeaderboardScope scope = LeaderboardScope.global,
  LeaderboardMetric metric = LeaderboardMetric.single,
}) {
  return LeaderboardView(
    scope: scope,
    metric: metric,
    isLoading: isLoading,
    isLoadingMore: isLoadingMore,
    isEmpty: isEmpty,
    failureMessage: failureMessage,
    leaderboard: leaderboard,
    pinnedViewer: pinnedViewer,
    onScopeChanged: (_) {},
    onMetricChanged: (_) {},
    onRetry: () {},
    onLoadMore: () {},
    onTapEntry: (_) {},
    formatTime: _fmt,
  );
}

/// The view uses Expanded, so it needs a bounded height — wrap in a Scaffold
/// body via harnessPage.
Widget _screen(LeaderboardView view) => Scaffold(body: SafeArea(child: view));

void main() {
  setUpAll(initTestFonts);

  const Size phone = Size(390, 780);

  group('LeaderboardView states', () {
    testWidgets('populated shows every rank, the gap and the pinned viewer',
        (WidgetTester tester) async {
      await tester.pumpWidget(harnessPage(_screen(_view()), size: phone));
      await tester.pumpAndSettle();

      expect(find.text('kian_r'), findsOneWidget);
      expect(find.text('emma_c'), findsOneWidget);
      // Country names, not flags or codes.
      expect(find.text('Iran'), findsOneWidget);
      expect(find.text('Uzbekistan'), findsOneWidget);
      // The gap indicator sits between the page and the pinned viewer.
      expect(find.byType(LeaderboardGap), findsOneWidget);
      // The viewer row, pinned, thousands-separated rank.
      expect(find.text('1,204'), findsOneWidget);
    });

    testWidgets(
        'pinned viewer row shows the literal "You", not the entry display name '
        '(spec §7)', (WidgetTester tester) async {
      // _viewer.displayName is 'kian_r' (a real username, as a backend would
      // return) — the pinned row must override it to "You".
      await tester.pumpWidget(harnessPage(_screen(_view()), size: phone));
      await tester.pumpAndSettle();

      // "You" appears exactly once — the pinned viewer row.
      expect(find.text('You'), findsOneWidget);
      // The pinned viewer's real username never renders in the pinned row; the
      // only 'kian_r' on screen is the rank-1 list entry.
      expect(find.text('kian_r'), findsOneWidget);

      // The "You" text is inside the pinned LeaderboardRow, whose rank is 1,204.
      final LeaderboardRow pinned = tester.widget<LeaderboardRow>(
        find.ancestor(
          of: find.text('You'),
          matching: find.byType(LeaderboardRow),
        ),
      );
      expect(pinned.nameOverride, 'You');
      expect(pinned.displayName, 'kian_r');
      expect(pinned.isCurrentUser, isTrue);
      expect(pinned.rank, 1204);
    });

    testWidgets('loading shows the loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        harnessPage(
          _screen(_view(isLoading: true, pinnedViewer: null)),
          size: phone,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byType(LeaderboardRow), findsNothing);
    });

    testWidgets('empty (friends scope) shows scope-specific copy',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harnessPage(
          _screen(
            _view(
              isEmpty: true,
              scope: LeaderboardScope.friends,
              leaderboard: const Leaderboard(entries: <LeaderboardEntry>[]),
              pinnedViewer: null,
            ),
          ),
          size: phone,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No friends ranked yet'), findsOneWidget);
      expect(find.byType(LeaderboardRow), findsNothing);
    });

    testWidgets('error shows the message and retry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harnessPage(
          _screen(
            _view(
              failureMessage: 'Could not load the leaderboard',
              leaderboard: null,
              pinnedViewer: null,
            ),
          ),
          size: phone,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load the leaderboard'), findsOneWidget);
    });
  });

  group('LeaderboardRow spec', () {
    Future<Color> rankColor(WidgetTester tester, int rank) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 360,
            child: LeaderboardRow(
              rank: rank,
              displayName: 'Someone',
              time: '6.31',
              countryCode: 'IR',
            ),
          ),
        ),
      );
      final Text rankText = tester.widget<Text>(find.text('$rank'));
      return rankText.style!.color!;
    }

    testWidgets('rank 1 renders in statusWarning', (WidgetTester tester) async {
      final Color c = await rankColor(tester, 1);
      expect(c, AppColors.light.statusWarning);
    });

    testWidgets('rank 3 renders in accentEnergy', (WidgetTester tester) async {
      final Color c = await rankColor(tester, 3);
      expect(c, AppColors.light.accentEnergy);
    });

    testWidgets('rank 2 is unaccented (textSecondary, no invented silver)',
        (WidgetTester tester) async {
      final Color c = await rankColor(tester, 2);
      expect(c, AppColors.light.textSecondary);
    });

    testWidgets('rank 4 (off podium) is textSecondary',
        (WidgetTester tester) async {
      final Color c = await rankColor(tester, 4);
      expect(c, AppColors.light.textSecondary);
    });

    testWidgets('unknown country falls back to the raw code',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 360,
            child: LeaderboardRow(
              rank: 9,
              displayName: 'Ghost',
              time: '9.99',
              countryCode: 'ZZ',
            ),
          ),
        ),
      );
      expect(find.text('ZZ'), findsOneWidget);
    });

    testWidgets('time is tabular and right-aligned in textPrimary',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 360,
            child: LeaderboardRow(
              rank: 5,
              displayName: 'Dana',
              time: '6.83',
              countryCode: 'US',
            ),
          ),
        ),
      );

      final Text timeText = tester.widget<Text>(find.text('6.83'));
      expect(timeText.style!.color, AppColors.light.textPrimary);
      expect(
        timeText.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );

      // Right-aligned: the time sits to the right of the name.
      final double nameRight = tester.getTopRight(find.text('Dana')).dx;
      final double timeLeft = tester.getTopLeft(find.text('6.83')).dx;
      expect(timeLeft, greaterThan(nameRight));
    });

    testWidgets('viewer row renders the time in brandPrimary',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 360,
            child: LeaderboardRow(
              rank: 1204,
              displayName: 'You',
              time: '8.42',
              countryCode: 'UZ',
              isCurrentUser: true,
            ),
          ),
        ),
      );

      final Text timeText = tester.widget<Text>(find.text('8.42'));
      expect(timeText.style!.color, AppColors.light.brandPrimary);
      // Thousands-separated rank.
      expect(find.text('1,204'), findsOneWidget);
    });
  });

  group('LeaderboardView goldens', () {
    Future<void> golden(
      WidgetTester tester,
      LeaderboardView view, {
      required String name,
      bool settle = true,
    }) async {
      for (final (String suffix, Brightness brightness)
          in <(String, Brightness)>[
        ('light', Brightness.light),
        ('dark', Brightness.dark),
      ]) {
        await tester.binding.setSurfaceSize(phone);
        await tester.pumpWidget(
          harnessPage(_screen(view), brightness: brightness, size: phone),
        );
        if (settle) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump(const Duration(milliseconds: 300));
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/leaderboard_view_${name}_$suffix.png'),
        );
      }
      await tester.binding.setSurfaceSize(null);
    }

    testWidgets('populated with pinned viewer', (WidgetTester tester) async {
      await golden(tester, _view(), name: 'populated');
    });

    testWidgets('empty', (WidgetTester tester) async {
      await golden(
        tester,
        _view(
          isEmpty: true,
          scope: LeaderboardScope.friends,
          leaderboard: const Leaderboard(entries: <LeaderboardEntry>[]),
          pinnedViewer: null,
        ),
        name: 'empty',
      );
    });

    testWidgets('error', (WidgetTester tester) async {
      await golden(
        tester,
        _view(
          failureMessage: 'Could not load the leaderboard',
          leaderboard: null,
          pinnedViewer: null,
        ),
        name: 'error',
      );
    });

    testWidgets('loading', (WidgetTester tester) async {
      await golden(
        tester,
        _view(isLoading: true, pinnedViewer: null),
        name: 'loading',
        settle: false,
      );
    });
  });
}
