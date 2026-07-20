import 'package:cubeclash/features/timer/domain/entities/scramble.dart';
import 'package:cubeclash/features/timer/domain/entities/scramble_source.dart';
import 'package:cubeclash/features/timer/domain/entities/wca_event.dart';
import 'package:cubeclash/features/timer/presentation/widgets/event_picker_sheet.dart';
import 'package:cubeclash/features/timer/presentation/widgets/scramble_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

void main() {
  setUpAll(initTestFonts);

  Widget card(Scramble scramble, WcaEvent event) => ScrambleCard(
        scramble: scramble,
        event: event,
        source: ScrambleSource.random,
        onNewScramble: () {},
        onSourceChanged: (_) {},
      );

  group('the scramble card adapts to the event', () {
    testWidgets('renders a 3×3 scramble at the frame size', (
      WidgetTester tester,
    ) async {
      final Scramble scramble = Scramble.parse(
        "R U R' U' F2 D B L2 F R' D2 U B2 L F' R2 D' L B U2",
        ScrambleNotation.faceTurns,
      );
      await tester.pumpWidget(
        harnessPage(card(scramble, WcaEvent.cube3x3)),
      );
      await tester.pump();

      expect(find.text(scramble.text), findsOneWidget);
      // Nothing to collapse at twenty moves on one line.
      expect(find.textContaining('more line'), findsNothing);
    });

    testWidgets('keeps Megaminx line breaks as separate paragraphs', (
      WidgetTester tester,
    ) async {
      final Scramble scramble = Scramble.parse(
        'R++ D-- R++ D-- U\n'
        'R++ D-- R-- D++ U\n'
        "R-- D++ R++ D++ U'",
        ScrambleNotation.faceTurns,
      );
      await tester.pumpWidget(
        harnessPage(card(scramble, WcaEvent.cube3x3)),
      );
      await tester.pump();

      // Three lines means three Text widgets, never one reflowed paragraph.
      for (final List<String> line in scramble.lines) {
        expect(find.text(line.join(' ')), findsOneWidget);
      }
      expect(find.text(scramble.text), findsNothing);
    });

    testWidgets('collapses a long scramble behind an expander', (
      WidgetTester tester,
    ) async {
      final Scramble scramble = Scramble.parse(
        List<String>.generate(7, (int i) => 'R$i U$i F$i').join('\n'),
        ScrambleNotation.faceTurns,
      );
      await tester.pumpWidget(
        harnessPage(card(scramble, WcaEvent.cube3x3)),
      );
      await tester.pump();

      // Four of seven lines shown, three behind the toggle.
      expect(find.text('Show 3 more lines'), findsOneWidget);
      expect(find.text('R6 U6 F6'), findsNothing);

      await tester.tap(find.text('Show 3 more lines'));
      await tester.pump();

      expect(find.text('R6 U6 F6'), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('numbers Multi-Blind\'s separate scrambles', (
      WidgetTester tester,
    ) async {
      final Scramble scramble = Scramble.parse(
        'R U F\nL D B\nU2 R2 F2',
        ScrambleNotation.multiScramble,
      );
      await tester.pumpWidget(
        harnessPage(card(scramble, WcaEvent.multiBlind)),
      );
      await tester.pump();

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
      expect(find.textContaining('3 cubes'), findsOneWidget);
    });

    testWidgets(
      'says so plainly for an event with no scrambler, and disables New',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          harnessPage(card(const Scramble.empty(), WcaEvent.megaminx)),
        );
        await tester.pump();

        expect(
          find.text('Megaminx scrambles are coming.'),
          findsOneWidget,
        );
        // Emphatically not a 3×3 scramble under a Megaminx label.
        expect(find.textContaining("R U R'"), findsNothing);

        // The `New` pill renders in its disabled treatment — there is nothing
        // for it to generate.
        final Opacity pill = tester.widget<Opacity>(
          find
              .ancestor(of: find.text('New'), matching: find.byType(Opacity))
              .first,
        );
        expect(pill.opacity, lessThan(1));
      },
    );
  });

  group('the event picker', () {
    Future<void> open(WidgetTester tester, {String selected = '3x3'}) async {
      await tester.pumpWidget(
        harnessPage(
          Scaffold(
            body: EventPickerSheet(
              selected: selected,
              recents: const <String>['3x3-oh', '4x4'],
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('groups the seventeen rather than listing them flat', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(find.text('CUBES'), findsOneWidget);

      // The rest are below the fold — a ListView does not build off-screen
      // children, so scrolling is how you assert they exist at all.
      final Finder list = find.byType(Scrollable).last;
      for (final String header in <String>[
        'OTHER PUZZLES',
        'BLINDFOLDED',
        'SPECIAL',
      ]) {
        await tester.scrollUntilVisible(
          find.text(header),
          200,
          scrollable: list,
        );
        expect(find.text(header), findsOneWidget, reason: header);
      }
    });

    testWidgets('pins recents above the groups', (WidgetTester tester) async {
      await open(tester);
      expect(find.text('RECENT'), findsOneWidget);

      // Recent sits above the first group, so the most recently practised
      // event is reachable without scrolling past the cubes.
      final double recentY = tester.getTopLeft(find.text('RECENT')).dy;
      final double cubesY = tester.getTopLeft(find.text('CUBES')).dy;
      expect(recentY, lessThan(cubesY));

      final double oneHandedY =
          tester.getTopLeft(find.text('3×3 One-Handed')).dy;
      expect(oneHandedY, greaterThan(recentY));
      expect(oneHandedY, lessThan(cubesY));
    });

    testWidgets('search matches the short name a cuber would type', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '3bld');
      await tester.pump();

      expect(find.text('3×3 Blindfolded'), findsOneWidget);
      expect(find.text('2×2 Cube'), findsNothing);
      // Recents are suppressed while searching — they would be noise.
      expect(find.text('RECENT'), findsNothing);
    });

    testWidgets('says so when nothing matches', (WidgetTester tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'gigaminx');
      await tester.pump();
      expect(find.textContaining('No event matches'), findsOneWidget);
    });

    testWidgets('lists an un-scramblable event enabled, with the caveat', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'skewb');
      await tester.pump();

      // Present and selectable — you can still time it. The subtitle carries
      // the one thing worth knowing before you commit.
      // Twice: the row title, and the short-name badge — which for Skewb is
      // the same string.
      expect(find.text('Skewb'), findsNWidgets(2));
      expect(
        find.text('Average of 5 · no scrambles yet'),
        findsOneWidget,
      );
    });
  });
}
