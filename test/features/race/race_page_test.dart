import 'package:bloc_test/bloc_test.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/core/realtime/race_gateway.dart';
import 'package:cubeclash/features/race/domain/entities/race_room.dart';
import 'package:cubeclash/features/race/presentation/bloc/race_bloc.dart';
import 'package:cubeclash/features/race/presentation/pages/live_race_page.dart';
import 'package:cubeclash/features/race/presentation/pages/race_page.dart';
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
    testWidgets('offers the three modes with quick match first',
        (WidgetTester tester) async {
      await pumpRace(tester, const RaceState());

      expect(find.text('Quick Match'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Tournaments'), findsOneWidget);
      expect(find.text('Find a match'), findsOneWidget);
    });

    testWidgets('tapping find a match enqueues', (WidgetTester tester) async {
      await pumpRace(tester, const RaceState());
      await tester.tap(find.text('Find a match'));
      await tester.pump();

      verify(() => bloc.add(const RaceRequested(RaceMode.quick))).called(1);
    });

    testWidgets('the private segment offers create and join',
        (WidgetTester tester) async {
      await pumpRace(tester, const RaceState());
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();

      expect(find.text('Create room'), findsOneWidget);
      expect(find.text('Join room'), findsOneWidget);
      expect(find.text('Invite code'), findsOneWidget);
    });

    testWidgets('tournaments render a designed coming-soon state',
        (WidgetTester tester) async {
      await pumpRace(tester, const RaceState());
      await tester.tap(find.text('Tournaments'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly 3×3 Open'), findsOneWidget);
      expect(find.text('Soon'), findsNWidgets(2));
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
      await pumpRace(
        tester,
        const RaceState(phase: RacePhase.searching),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      verify(() => bloc.add(const RaceCancelled())).called(1);
    });
  });

  group('ready room', () {
    testWidgets('lists both players with live ready state',
        (WidgetTester tester) async {
      await pumpRace(
        tester,
        RaceState(
          phase: RacePhase.readyCheck,
          room: roomOf(theyReady: true),
        ),
      );

      expect(find.text('You'), findsOneWidget);
      expect(find.text('Kenji Sato'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Not ready'), findsOneWidget);
      expect(find.text("I'm ready"), findsOneWidget);
    });

    testWidgets('once you are ready the button waits rather than re-firing',
        (WidgetTester tester) async {
      await pumpRace(
        tester,
        RaceState(phase: RacePhase.readyCheck, room: roomOf(youReady: true)),
      );

      expect(find.text('Waiting for them…'), findsOneWidget);
      expect(find.text("I'm ready"), findsNothing);
    });

    testWidgets('a disconnected opponent is called out',
        (WidgetTester tester) async {
      await pumpRace(
        tester,
        RaceState(
          phase: RacePhase.readyCheck,
          room: roomOf(theyConnected: false),
        ),
      );

      expect(find.text('Reconnecting…'), findsOneWidget);
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
      expect(find.text('SCRAMBLE'), findsNothing);
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

    testWidgets('racing shows scramble, your clock and their progress',
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

      expect(find.text("R U R' U' F2"), findsOneWidget);
      expect(find.text('7.42'), findsOneWidget);
      expect(find.text('5.10'), findsOneWidget);
      expect(find.text('Tap anywhere to stop'), findsOneWidget);
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

      await tester.tap(find.text('7.42'));
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

    testWidgets('after submitting you wait on the opponent',
        (WidgetTester tester) async {
      await pumpLive(
        tester,
        RaceState(
          phase: RacePhase.submitted,
          yourTimeMs: 9870,
          room: roomOf(status: RaceStatus.racing, theirProgress: 6000),
        ),
      );

      expect(find.text('YOUR TIME'), findsOneWidget);
      expect(find.text('9.87'), findsOneWidget);
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
    testWidgets('a win shows both times, the delta and the Elo change',
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

      expect(find.text('Win'), findsOneWidget);
      expect(find.text('9.87'), findsOneWidget);
      expect(find.text('12.34'), findsOneWidget);
      expect(find.text('You won by 2.47'), findsOneWidget);
      expect(find.text('+18 Elo'), findsOneWidget);
      expect(find.text('Rematch'), findsOneWidget);
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

      expect(find.text('Loss'), findsOneWidget);
      expect(find.text('You lost by 1.50'), findsOneWidget);
      expect(find.text('-12 Elo'), findsOneWidget);
    });

    testWidgets('an opponent DNF shows DNF and no delta',
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

      expect(find.text('Win'), findsOneWidget);
      expect(find.text('DNF'), findsOneWidget);
      expect(find.textContaining('won by'), findsNothing);
    });

    testWidgets('an opponent walking away reads as a win by default',
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

      expect(find.text('Win by default'), findsOneWidget);
      expect(find.text('Your opponent disconnected.'), findsOneWidget);
    });

    testWidgets('rematch and back-to-lobby both fire',
        (WidgetTester tester) async {
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

      await tester.tap(find.text('Back to lobby'));
      await tester.pump();
      verify(() => bloc.add(const RaceDismissed())).called(1);
    });
  });
}
