import 'package:cubeclash/features/stats/domain/entities/leaderboard_entry.dart';
import 'package:cubeclash/features/stats/presentation/widgets/head_to_head_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

/// The two states this card exists to keep apart.
///
/// The server sends `head_to_head: null` when two accounts have never raced,
/// and an object when they have. A present `{wins: 0, losses: 0}` therefore
/// means "we have raced, nobody won" — reachable whenever every shared race
/// ended in a mutual DNF, because the server counts only `win` and `loss`
/// outcomes and tracks `dnf`/`left` separately.
///
/// The page used to test `record == null || record.total == 0`, which reported
/// a real shared history as "you haven't raced yet".
void main() {
  setUpAll(initTestFonts);

  Future<void> pump(WidgetTester tester, HeadToHead? record) =>
      tester.pumpWidget(
        harness(HeadToHeadCard(record: record, opponentName: 'kian_r')),
      );

  testWidgets('null record reads as never raced', (WidgetTester tester) async {
    await pump(tester, null);

    expect(find.text("You haven't raced kian_r yet"), findsOneWidget);
  });

  testWidgets('0-0 is a raced record, not an absent one',
      (WidgetTester tester) async {
    await pump(tester, const HeadToHead(wins: 0, losses: 0));

    // The distinction this whole widget exists for.
    expect(find.text("You haven't raced kian_r yet"), findsNothing);
    expect(find.text('No decided races yet'), findsOneWidget);
    // The tally is shown, both sides on zero.
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('kian_r'), findsOneWidget);
  });

  testWidgets('a decided record shows the tally and a plural count',
      (WidgetTester tester) async {
    await pump(tester, const HeadToHead(wins: 3, losses: 1));

    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4 decided races'), findsOneWidget);
  });

  testWidgets('a single decided race is singular', (WidgetTester tester) async {
    await pump(tester, const HeadToHead(wins: 1, losses: 0));

    expect(find.text('1 decided race'), findsOneWidget);
  });

  test('decided counts only settled wins and losses', () {
    // Named `decided`, not `total`, because the server also tracks `dnf` and
    // `left` outcomes it does not send — the played count is not knowable here.
    expect(const HeadToHead(wins: 2, losses: 3).decided, 5);
    expect(const HeadToHead(wins: 0, losses: 0).decided, 0);
  });
}
