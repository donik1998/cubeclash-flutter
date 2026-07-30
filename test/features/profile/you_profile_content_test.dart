import 'package:cubeclash/features/profile/domain/entities/profile_summary.dart';
import 'package:cubeclash/features/profile/presentation/widgets/profile_content.dart';
import 'package:cubeclash/features/profile/presentation/widgets/profile_menu_row.dart';
import 'package:cubeclash/core/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

/// Behaviour tests for the pure You · Profile body: the §6 drop rules, the §9
/// client-side formatting, and the three navigation callbacks.
void main() {
  setUpAll(initTestFonts);

  ProfileSummary summary({
    String displayName = 'cuber_98',
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
    int friendCount = 48,
  }) =>
      ProfileSummary(
        id: 'me',
        displayName: displayName,
        countryCode: countryCode,
        elo: elo,
        rank: rank,
        bestSingleMs: bestSingleMs,
        bestSingleEvent: '3x3',
        totalSolves: totalSolves,
        winRate: winRate,
        wins: 217,
        losses: 102,
        friendCount: friendCount,
      );

  Future<void> pump(
    WidgetTester tester,
    ProfileSummary data, {
    VoidCallback? onFriends,
    VoidCallback? onShare,
    VoidCallback? onSettings,
  }) async {
    await tester.pumpWidget(
      harnessPage(
        ProfileContent(
          summary: data,
          isLoading: false,
          hasError: false,
          onRetry: () {},
          onFriends: onFriends ?? () {},
          onShare: onShare ?? () {},
          onSettings: onSettings ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nominal renders the whole subtitle and formatted stats',
      (WidgetTester tester) async {
    await pump(tester, summary());

    expect(find.text('Uzbekistan · Elo 1180 · #1,204'), findsOneWidget);
    expect(find.text('8.42'), findsOneWidget); // best, ms → seconds
    expect(find.text('3,204'), findsOneWidget); // solves, grouped
    expect(find.text('68%'), findsOneWidget); // win rate, ratio → percent
    expect(find.text('48'), findsOneWidget); // friend count, trailing
    expect(find.text('cuber_98'), findsOneWidget);
    expect(find.text('C'), findsOneWidget); // avatar initial
  });

  testWidgets('no country drops the country segment',
      (WidgetTester tester) async {
    await pump(tester, summary(countryCode: null));
    expect(find.text('Elo 1180 · #1,204'), findsOneWidget);
  });

  testWidgets('null rank drops the "#" segment', (WidgetTester tester) async {
    await pump(tester, summary(rank: null, elo: 1000));
    expect(find.text('Uzbekistan · Elo 1000'), findsOneWidget);
  });

  testWidgets('null best / win rate render em-dash',
      (WidgetTester tester) async {
    await pump(tester, summary(bestSingleMs: null, winRate: null));
    // best "—" and win-rate "—" → two em-dashes.
    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('zero solves and zero friends render "0"',
      (WidgetTester tester) async {
    await pump(tester, summary(totalSolves: 0, friendCount: 0));
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('ten-thousands rank is grouped', (WidgetTester tester) async {
    await pump(
      tester,
      summary(
        rank: const ProfileRank(
          event: '3x3',
          metric: 'single',
          scope: 'global',
          position: 12048,
        ),
      ),
    );
    expect(find.textContaining('#12,048'), findsOneWidget);
  });

  testWidgets('menu rows fire their callbacks', (WidgetTester tester) async {
    var friends = 0;
    var share = 0;
    var settings = 0;
    await pump(
      tester,
      summary(),
      onFriends: () => friends++,
      onShare: () => share++,
      onSettings: () => settings++,
    );

    await tester.tap(find.text('Friends'));
    await tester.tap(find.text('Share profile'));
    await tester.tap(find.text('Settings'));
    await tester.pump();

    expect(friends, 1);
    expect(share, 1);
    expect(settings, 1);
    expect(find.byType(ProfileMenuRow), findsNWidgets(3));
  });

  testWidgets('error state shows retry', (WidgetTester tester) async {
    var retried = 0;
    await tester.pumpWidget(
      harnessPage(
        ProfileContent(
          summary: null,
          isLoading: false,
          hasError: true,
          errorMessage: 'boom',
          onRetry: () => retried++,
          onFriends: () {},
          onShare: () {},
          onSettings: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });
}
