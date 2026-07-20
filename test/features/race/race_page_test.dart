import 'package:bloc_test/bloc_test.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/core/realtime/race_gateway.dart';
import 'package:cubeclash/features/race/domain/entities/race_room.dart';
import 'package:cubeclash/features/race/presentation/bloc/race_bloc.dart';
import 'package:cubeclash/features/race/presentation/pages/live_race_page.dart';
import 'package:cubeclash/features/race/presentation/pages/race_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/harness.dart';

class _MockRaceBloc extends MockBloc<RaceEvent, RaceState>
    implements RaceBloc {}

void main() {
  setUpAll(initTestFonts);

  late _MockRaceBloc bloc;

  setUp(() async {
    await configureDependencies();
    bloc = _MockRaceBloc();
    sl.unregister<RaceBloc>();
    sl.registerSingleton<RaceBloc>(bloc);
  });

  tearDown(resetDependencies);

  const RacePlayer you = RacePlayer(
    userId: 'me',
    displayName: 'You',
    countryCode: 'GB',
    isYou: true,
  );
  const RacePlayer them = RacePlayer(
    userId: 'them',
    displayName: 'Kenji Sato',
    countryCode: 'JP',
  );

  RaceRoom roomOf({
    RaceStatus status = RaceStatus.readyCheck,
    bool youReady = false,
    bool theyReady = false,
    bool theyConnected = true,
    int? theirProgress,
    String? code,
  }) =>
      RaceRoom(
        id: 'r1',
        status: status,
        code: code,
        players: <RacePlayer>[
          you.copyWith(ready: youReady),
          them.copyWith(
            ready: theyReady,
            connected: theyConnected,
            progressMs: theirProgress,
          ),
        ],
      );

  Future<void> pumpRace(WidgetTester tester, RaceState state) async {
    whenListen(bloc, const Stream<RaceState>.empty(), initialState: state);
    await tester.pumpWidget(harnessPage(const RacePage()));
    await tester.pump();
  }

  Future<void> pumpLive(WidgetTester tester, RaceState state) async {
    whenListen(bloc, const Stream<RaceState>.empty(), initialState: state);
    await tester.pumpWidget(harnessPage(const LiveRacePage()));
    await tester.pump();
  }

  group('lobby', () {
    testWidgets('titles itself and offers the three modes',
        (WidgetTester tester) async {
      await pumpRace(tester, const RaceState());

      expect(find.text('Race'), findsOneWidget);
      expect(find.text('Quick Match'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Tournaments'), findsOneWidget);
      expect(find.text('Race a random cuber'), findsOneWidget);
      expect(find.text('Find a match'), findsOneWidget);
    });

    testWidgets('tapping find a match enqueues', (WidgetTester tester) async {
      await pumpRace(tester, const RaceState());
      await tester.tap(find.text('Find a match'));
      await tester.pump();

      verify(() => bloc.add(const RaceRequested(RaceMode.quick, event: '3x3')))
          .called(1);
    });

    testWidgets('the private segment offers create and join',
        (WidgetTester tester) async {
      await pumpRace(tester, const RaceState());
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();

      expect(find.text('Create a room'), findsOneWidget);
      expect(find.text('Join a room'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
    });

    testWidgets('no room code before a room exists',
        (WidgetTester tester) async {
      await pumpRace(tester, const RaceState());
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();

      // The frame shows a code because its mock has one. There is nothing to
      // copy until you have actually created a room.
      expect(find.text('YOUR ROOM CODE'), findsNothing);
    });

    testWidgets('a created room shows its code and a copy affordance',
        (WidgetTester tester) async {
      await pumpRace(
        tester,
        RaceState(room: roomOf(status: RaceStatus.waiting, code: 'CUBE-4821')),
      );
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();

      expect(find.text('YOUR ROOM CODE'), findsOneWidget);
      expect(find.text('CUBE-4821'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('every tournament reads as unbuilt, not live',
        (WidgetTester tester) async {
      await pumpRace(tester, const RaceState());
      await tester.tap(find.text('Tournaments'));
      await tester.pumpAndSettle();

      expect(find.text('Global Weekly · 3×3'), findsOneWidget);
      // The frame's first card is a LIVE tournament with an Enter button.
      // There is no tournament backend, so nothing claims to be running.
      expect(find.text('SOON'), findsNWidgets(3));
      expect(find.text('LIVE'), findsNothing);
    });
  });

  group('matchmaking', () {
    testWidgets('shows the elapsed wait and a cancel',
        (WidgetTester tester) async {
      await pumpRace(
        tester,
        const RaceState(
          phase: RacePhase.searching,
          searchElapsed: Duration(seconds: 12),
        ),
      );

      expect(find.text('Finding an opponent'), findsOneWidget);
      expect(find.text('12s'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('formats a long wait as minutes and seconds',
        (WidgetTester tester) async {
      await pumpRace(
        tester,
        const RaceState(
          phase: RacePhase.searching,
          searchElapsed: Duration(seconds: 95),
        ),
      );

      expect(find.text('1m 35s'), findsOneWidget);
    });

    testWidgets('a private room shows its shareable code',
        (WidgetTester tester) async {
      await pumpRace(
        tester,
        RaceState(
          phase: RacePhase.searching,
          mode: RaceMode.private,
          room: roomOf(status: RaceStatus.waiting, code: 'HJKMNP'),
        ),
      );

      expect(find.text('Waiting for your opponent'), findsOneWidget);
      expect(find.text('HJKMNP'), findsOneWidget);
    });

    testWidgets('cancel fires', (WidgetTester tester) async {
      await pumpRace(tester, const RaceState(phase: RacePhase.searching));
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      verify(() => bloc.add(const RaceCancelled())).called(1);
    });
  });

  group('versus chrome', () {
    testWidgets('names both players and their countries in words',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(phase: RacePhase.readyCheck, room: roomOf()),
      );

      expect(find.text('You'), findsOneWidget);
      expect(find.text('Kenji Sato'), findsOneWidget);
      expect(find.text('United Kingdom'), findsOneWidget);
      expect(find.text('Japan'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
    });

    testWidgets('both clocks render, neither as a hero',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.racing,
          scramble: "R U R' U' F2",
          elapsed: const Duration(milliseconds: 7420),
          room: roomOf(status: RaceStatus.racing, theirProgress: 5100),
        ),
      );

      expect(find.text('7.42'), findsOneWidget);
      expect(find.text('5.10'), findsOneWidget);
      expect(find.text('SAME SCRAMBLE'), findsOneWidget);
      expect(find.text("R U R' U' F2"), findsOneWidget);
      expect(find.text('Tap anywhere to stop'), findsOneWidget);
    });

    testWidgets('the close affordance clears a 48dp target',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(phase: RacePhase.readyCheck, room: roomOf()),
      );

      final Size size = tester.getSize(
        find
            .ancestor(
              of: find.text('×'),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('closing the ready room leaves the race',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(phase: RacePhase.readyCheck, room: roomOf()),
      );
      await tester.tap(find.text('×'));
      await tester.pump();

      verify(() => bloc.add(const RaceCancelled())).called(1);
    });

    testWidgets('there is no way out mid-solve', (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.racing,
          scramble: 'R U',
          room: roomOf(status: RaceStatus.racing),
        ),
      );

      // The whole surface is the stop button, so a × here could never be hit.
      expect(find.text('×'), findsNothing);
    });
  });

  group('ready check', () {
    testWidgets('shows each side’s ready state', (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(phase: RacePhase.readyCheck, room: roomOf(theyReady: true)),
      );

      expect(find.text('READY UP?'), findsOneWidget);
      expect(find.text('You: not ready'), findsOneWidget);
      expect(find.text('Kenji Sato: ready'), findsOneWidget);
      expect(find.text("I'm ready"), findsOneWidget);
    });

    testWidgets('once you are ready the button waits rather than re-firing',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(phase: RacePhase.readyCheck, room: roomOf(youReady: true)),
      );

      expect(find.text('Waiting for them…'), findsOneWidget);
      expect(find.text("I'm ready"), findsNothing);
    });

    testWidgets('readying up fires', (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(phase: RacePhase.readyCheck, room: roomOf()),
      );
      await tester.tap(find.text("I'm ready"));
      await tester.pump();

      verify(() => bloc.add(const RaceReadyPressed())).called(1);
    });

    testWidgets('a disconnected opponent is called out',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.readyCheck,
          room: roomOf(theyConnected: false),
        ),
      );

      expect(find.text('Reconnecting…'), findsOneWidget);
    });

    testWidgets('both clocks read zero before the solve starts',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.readyCheck,
          // A progress value left over from the previous race.
          room: roomOf(theirProgress: 5100),
        ),
      );

      expect(find.text('0.00'), findsNWidgets(2));
      expect(find.text('5.10'), findsNothing);
    });

    testWidgets('the scramble is withheld until GO',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(phase: RacePhase.readyCheck, room: roomOf()),
      );

      // The Figma ready-room frame shows a scramble; the protocol reveals it
      // at GO, and handing it over early would give one side a head start.
      expect(find.text('SAME SCRAMBLE'), findsNothing);
    });
  });

  group('live race', () {
    testWidgets('countdown shows the tick and no scramble',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.countdown,
          countdown: 2,
          room: roomOf(status: RaceStatus.countdown),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      expect(find.text('SAME SCRAMBLE'), findsNothing);
    });

    testWidgets('GO is rendered as a word', (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.countdown,
          countdown: 0,
          room: roomOf(status: RaceStatus.countdown),
        ),
      );

      expect(find.text('GO'), findsOneWidget);
    });

    testWidgets('tapping stops the solve', (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.racing,
          scramble: 'R U',
          elapsed: const Duration(milliseconds: 7420),
          room: roomOf(status: RaceStatus.racing),
        ),
      );

      await tester.tap(find.text('Tap anywhere to stop'));
      await tester.pump();

      verify(() => bloc.add(const RaceSolveStopped())).called(1);
    });

    testWidgets('your own disconnect is explained, not hidden',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.racing,
          scramble: 'R U',
          elapsed: const Duration(milliseconds: 3000),
          room: roomOf(status: RaceStatus.racing),
          connection: GatewayConnection.disconnected,
        ),
      );

      expect(
        find.text('Reconnecting — your time is still being recorded.'),
        findsOneWidget,
      );
    });

    testWidgets('after submitting your clock freezes and you wait',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.submitted,
          yourTimeMs: 9870,
          room: roomOf(status: RaceStatus.racing, theirProgress: 6000),
        ),
      );

      expect(find.text('9.87'), findsOneWidget);
      expect(find.text('6.00'), findsOneWidget);
      expect(find.text('Waiting for your opponent to finish'), findsOneWidget);
    });

    testWidgets('an opponent dropping while you wait is surfaced',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.submitted,
          yourTimeMs: 9870,
          room: roomOf(status: RaceStatus.racing, theyConnected: false),
        ),
      );

      expect(
        find.text('Your opponent dropped — waiting for them to reconnect'),
        findsOneWidget,
      );
    });
  });

  group('result', () {
    testWidgets('a win shows both times, the scoreline and the Elo change',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.settled,
          yourTimeMs: 9870,
          room: roomOf(status: RaceStatus.settled),
          result: const RaceResult(
            outcome: RaceOutcome.win,
            yourTimeMs: 9870,
            opponentTimeMs: 12340,
            eloDelta: 18,
          ),
        ),
      );

      expect(find.text('YOU WIN'), findsOneWidget);
      expect(find.text('9.87'), findsOneWidget);
      expect(find.text('12.34'), findsOneWidget);
      expect(find.text('9.87s   vs   12.34s'), findsOneWidget);
      expect(find.text('+18 Elo'), findsOneWidget);
      expect(find.text('Rematch'), findsOneWidget);
      expect(find.text('Lobby'), findsOneWidget);
    });

    testWidgets('a loss shows a negative Elo change',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.settled,
          yourTimeMs: 13000,
          room: roomOf(status: RaceStatus.settled),
          result: const RaceResult(
            outcome: RaceOutcome.loss,
            yourTimeMs: 13000,
            opponentTimeMs: 11500,
            eloDelta: -12,
          ),
        ),
      );

      expect(find.text('YOU LOSE'), findsOneWidget);
      expect(find.text('13.00s   vs   11.50s'), findsOneWidget);
      expect(find.text('-12 Elo'), findsOneWidget);
    });

    testWidgets('an opponent DNF shows DNF on their side',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.settled,
          room: roomOf(status: RaceStatus.settled),
          result: const RaceResult(
            outcome: RaceOutcome.win,
            yourTimeMs: 14000,
            opponentDnf: true,
          ),
        ),
      );

      expect(find.text('YOU WIN'), findsOneWidget);
      // Once on the card, once in the scoreline.
      expect(find.text('DNF'), findsOneWidget);
      expect(find.text('14.00s   vs   DNF'), findsOneWidget);
    });

    testWidgets('an opponent walking away is explained',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.settled,
          room: roomOf(status: RaceStatus.settled),
          result: const RaceResult(
            outcome: RaceOutcome.win,
            yourTimeMs: 11000,
            opponentLeft: true,
          ),
        ),
      );

      expect(find.text('YOU WIN'), findsOneWidget);
      expect(find.text('Your opponent disconnected.'), findsOneWidget);
    });

    testWidgets('rematch and lobby both fire', (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.settled,
          room: roomOf(status: RaceStatus.settled),
          result: const RaceResult(
            outcome: RaceOutcome.win,
            yourTimeMs: 9000,
            opponentTimeMs: 10000,
          ),
        ),
      );

      await tester.tap(find.text('Rematch'));
      await tester.pump();
      verify(() => bloc.add(const RaceRematchRequested())).called(1);

      await tester.tap(find.text('Lobby'));
      await tester.pump();
      verify(() => bloc.add(const RaceDismissed())).called(1);
    });
  });

  group('a stalled race', () {
    testWidgets('offers no way out while the wait is still normal',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.submitted,
          yourTimeMs: 9870,
          room: roomOf(status: RaceStatus.racing),
        ),
      );

      expect(find.text('Waiting for your opponent to finish'), findsOneWidget);
      expect(find.text('Back to lobby'), findsNothing);
    });

    testWidgets('surfaces an exit once the result is overdue',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.submitted,
          yourTimeMs: 9870,
          resultOverdue: true,
          room: roomOf(status: RaceStatus.racing),
        ),
      );

      expect(find.text("We've lost touch with the race"), findsOneWidget);
      // The reassurance matters as much as the button: without it, leaving
      // reads as forfeiting and nobody takes the exit.
      expect(
        find.textContaining('already submitted and will still count'),
        findsOneWidget,
      );
      expect(find.text('Back to lobby'), findsOneWidget);
    });

    testWidgets('the exit dismisses rather than cancelling',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.submitted,
          yourTimeMs: 9870,
          resultOverdue: true,
          room: roomOf(status: RaceStatus.racing),
        ),
      );

      await tester.tap(find.text('Back to lobby'));
      await tester.pump();

      // Dismiss keeps the submitted time with the server; cancel would leave
      // the room and could be read as a forfeit.
      verify(() => bloc.add(const RaceDismissed())).called(1);
      verifyNever(() => bloc.add(const RaceCancelled()));
    });
  });
}
