import 'package:cubeclash/core/analytics/analytics_service.dart';
import 'package:cubeclash/core/realtime/race_gateway.dart';
import 'package:cubeclash/features/race/domain/entities/race_room.dart';
import 'package:cubeclash/features/race/presentation/bloc/race_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_race_gateway_controller.dart';
import '../../support/fake_ticker.dart';

/// The race is a distributed system, so these tests are mostly about the ways
/// it goes wrong: disconnects, double submits, DNFs, and an opponent who never
/// readies.
void main() {
  late ControllableRaceGateway gateway;
  late FakeTicker ticker;
  late RaceBloc bloc;

  const ({bool connected, String id, String name, bool ready}) opponent =
      (id: 'them', name: 'Kenji Sato', ready: false, connected: true);
  const ({bool connected, String id, String name, bool ready}) readyOpponent =
      (id: 'them', name: 'Kenji Sato', ready: true, connected: true);

  /// Lets queued stream events and bloc handlers drain.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  setUp(() {
    gateway = ControllableRaceGateway();
    ticker = FakeTicker();
    bloc = RaceBloc(
      gateway: gateway,
      analytics: const NoopAnalytics(),
      ticker: ticker,
    );
  });

  tearDown(() async {
    await bloc.close();
    await ticker.dispose();
    await gateway.dispose();
  });

  /// Drives the room all the way to a running solve.
  Future<void> raceToRacing() async {
    bloc.add(const RaceOpened());
    await settle();

    bloc.add(const RaceRequested(RaceMode.quick));
    await settle();

    gateway.emitState(status: 'ready-check', opponent: opponent);
    await settle();

    bloc.add(const RaceReadyPressed());
    await settle();
    gateway.emitReadyUpdate('them');
    await settle();

    for (final int n in <int>[3, 2, 1, 0]) {
      gateway.emitCountdown(n);
      await settle();
    }

    gateway.emitScramble("R U R' U' F2 D B L2 F R'");
    await settle();
  }

  group('lifecycle', () {
    test('opening the tab connects exactly once', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceOpened());
      await settle();

      expect(gateway.connectCalls, 1);
    });

    test('quick match enqueues and starts the wait clock', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceRequested(RaceMode.quick));
      await settle();

      expect(bloc.state.phase, RacePhase.searching);
      expect(gateway.createdRaces.single.mode, 'quick');

      ticker.emit(const Duration(seconds: 7));
      await settle();
      expect(bloc.state.searchElapsed, const Duration(seconds: 7));
    });

    test('an opponent appearing moves to ready-check', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceRequested(RaceMode.quick));
      await settle();

      gateway.emitState(status: 'ready-check', opponent: opponent);
      await settle();

      expect(bloc.state.phase, RacePhase.readyCheck);
      expect(bloc.state.opponent?.displayName, 'Kenji Sato');
      expect(bloc.state.you?.isYou, isTrue);
    });

    test('a private room carries its invite code', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceRequested(RaceMode.private));
      await settle();

      gateway.emitState(status: 'waiting', code: 'HJKMNP');
      await settle();

      expect(bloc.state.room?.code, 'HJKMNP');
      expect(bloc.state.phase, RacePhase.searching);
    });

    test('joining by code normalises the input', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceJoinRequested('  hjkmnp '));
      await settle();

      expect(gateway.joinedCodes.single, 'HJKMNP');
    });

    test('joining with an empty code fails without hitting the gateway',
        () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceJoinRequested('   '));
      await settle();

      expect(gateway.joinedCodes, isEmpty);
      expect(bloc.state.failure, isNotNull);
      expect(bloc.state.phase, RacePhase.idle);
    });

    test('cancelling leaves the room and returns to the lobby', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceRequested(RaceMode.quick));
      await settle();
      bloc.add(const RaceCancelled());
      await settle();

      expect(bloc.state.phase, RacePhase.idle);
      expect(gateway.leaveCalls, greaterThanOrEqualTo(1));
    });
  });

  group('ready check', () {
    test('pressing ready is optimistic and emitted once', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceRequested(RaceMode.quick));
      await settle();
      gateway.emitState(status: 'ready-check', opponent: opponent);
      await settle();

      bloc.add(const RaceReadyPressed());
      await settle();

      expect(bloc.state.you?.ready, isTrue);
      expect(gateway.readyCalls, 1);

      // Pressing again must not re-emit.
      bloc.add(const RaceReadyPressed());
      await settle();
      expect(gateway.readyCalls, 1);
    });

    test('an opponent who never readies leaves the race waiting', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceRequested(RaceMode.quick));
      await settle();
      gateway.emitState(status: 'ready-check', opponent: opponent);
      await settle();
      bloc.add(const RaceReadyPressed());
      await settle();

      expect(bloc.state.phase, RacePhase.readyCheck);
      expect(bloc.state.room?.everyoneReady, isFalse);
      // Immersive from the ready check on — you are in a room with someone.
      expect(bloc.state.isImmersive, isTrue);
    });

    test('both ready is reflected in the room', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceRequested(RaceMode.quick));
      await settle();
      gateway.emitState(status: 'ready-check', opponent: readyOpponent);
      await settle();
      bloc.add(const RaceReadyPressed());
      await settle();

      expect(bloc.state.room?.everyoneReady, isTrue);
    });
  });

  group('countdown and start', () {
    test('counts 3-2-1-GO and only reveals the scramble at GO', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceRequested(RaceMode.quick));
      await settle();
      gateway.emitState(status: 'ready-check', opponent: readyOpponent);
      await settle();

      gateway.emitCountdown(3);
      await settle();
      expect(bloc.state.phase, RacePhase.countdown);
      expect(bloc.state.countdown, 3);
      expect(
        bloc.state.scramble,
        isEmpty,
        reason: 'knowing the scramble early would defeat a synchronised start',
      );

      gateway.emitCountdown(0);
      await settle();
      expect(bloc.state.countdown, 0);

      gateway.emitScramble('R U F');
      await settle();
      expect(bloc.state.phase, RacePhase.racing);
      expect(bloc.state.scramble, 'R U F');
      expect(bloc.state.countdown, isNull);
      expect(gateway.solveStartCalls, 1);
    });

    test('the solve clock runs during racing', () async {
      await raceToRacing();

      ticker.emit(const Duration(milliseconds: 4200));
      await settle();
      expect(bloc.state.elapsed, const Duration(milliseconds: 4200));
    });

    test('countdown and racing are immersive', () async {
      await raceToRacing();
      expect(bloc.state.isImmersive, isTrue);
    });
  });

  group('opponent progress', () {
    test('is tracked on the opponent', () async {
      await raceToRacing();

      gateway.emitOpponentProgress(3400);
      await settle();

      expect(bloc.state.opponent?.progressMs, 3400);
    });

    test('a state snapshot does not blank the opponent progress bar', () async {
      await raceToRacing();
      gateway.emitOpponentProgress(3400);
      await settle();

      // race:state carries no running_ms — a naive replace would lose it.
      gateway.emitState(status: 'racing', opponent: readyOpponent);
      await settle();

      expect(bloc.state.opponent?.progressMs, 3400);
    });
  });

  group('submitting', () {
    test('submits your time once and moves to the waiting phase', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 11230));
      await settle();

      bloc.add(const RaceSolveStopped());
      await settle();

      expect(gateway.submittedTimes, <int>[11230]);
      expect(bloc.state.phase, RacePhase.submitted);
      expect(bloc.state.yourTimeMs, 11230);
      expect(bloc.state.waitingForOpponent, isTrue);
    });

    test('a duplicate submit is ignored', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 11230));
      await settle();

      bloc.add(const RaceSolveStopped());
      bloc.add(const RaceSolveStopped());
      bloc.add(const RaceSolveStopped());
      await settle();

      expect(
        gateway.submittedTimes,
        <int>[11230],
        reason: 'a double-tap must never send a second time',
      );
    });

    test('the clock stops on submit — a late tick cannot alter your time',
        () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 11230));
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();

      ticker.emit(const Duration(milliseconds: 99999));
      await settle();

      expect(bloc.state.yourTimeMs, 11230);
      expect(bloc.state.elapsed, const Duration(milliseconds: 11230));
    });

    test('stopping before the race starts does nothing', () async {
      bloc.add(const RaceOpened());
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();

      expect(gateway.submittedTimes, isEmpty);
    });

    test('a racing snapshot does not drag you back out of submitted', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 9000));
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();

      // The room stays `racing` until the opponent finishes.
      gateway.emitState(status: 'racing', opponent: readyOpponent);
      await settle();

      expect(bloc.state.phase, RacePhase.submitted);
    });
  });

  group('results — the server decides', () {
    test('a win carries both times, the delta and the Elo change', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 9870));
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();

      gateway.emitResult(
        result: 'win',
        yourTime: 9870,
        oppTime: 12340,
        eloDelta: 18,
      );
      await settle();

      expect(bloc.state.phase, RacePhase.settled);
      expect(bloc.state.result?.isWin, isTrue);
      expect(bloc.state.result?.deltaMs, 2470);
      expect(bloc.state.result?.eloDelta, 18);
    });

    test('a loss is rendered as sent, not inferred from the times', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 8000));
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();

      // Deliberately contradictory: your time is faster, but the server says
      // you lost (a rejected solve, say). The client must not second-guess it.
      gateway.emitResult(
        result: 'loss',
        yourTime: 8000,
        oppTime: 12000,
        eloDelta: -11,
      );
      await settle();

      expect(bloc.state.result?.outcome, RaceOutcome.loss);
      expect(bloc.state.result?.isWin, isFalse);
    });

    test('an opponent DNF is a win with no delta', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 15000));
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();

      gateway.emitResult(
        result: 'win',
        yourTime: 15000,
        opponentDnf: true,
        eloDelta: 9,
      );
      await settle();

      expect(bloc.state.result?.isWin, isTrue);
      expect(bloc.state.result?.opponentDnf, isTrue);
      expect(bloc.state.result?.deltaMs, isNull);
    });

    test('both DNF settles without a delta', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 30000));
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();

      gateway.emitResult(
        result: 'dnf',
        yourDnf: true,
        opponentDnf: true,
      );
      await settle();

      expect(bloc.state.result?.outcome, RaceOutcome.dnf);
      expect(bloc.state.result?.deltaMs, isNull);
      expect(bloc.state.phase, RacePhase.settled);
    });

    test('an opponent who leaves past the grace window forfeits', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 10000));
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();

      gateway.emitResult(
        result: 'win',
        yourTime: 10000,
        opponentLeft: true,
        eloDelta: 5,
      );
      await settle();

      expect(bloc.state.result?.opponentLeft, isTrue);
      expect(bloc.state.result?.isWin, isTrue);
    });
  });

  group('disconnects', () {
    test('an opponent inside the grace window is flagged, not written off',
        () async {
      await raceToRacing();

      gateway.emitState(
        status: 'racing',
        opponent: (
          id: 'them',
          name: 'Kenji Sato',
          ready: true,
          connected: false,
        ),
      );
      await settle();

      expect(bloc.state.opponentReconnecting, isTrue);
      expect(
        bloc.state.phase,
        RacePhase.racing,
        reason: 'the client never rules on a disconnect — the server does',
      );
    });

    test('progress arriving clears a stale reconnecting flag', () async {
      await raceToRacing();
      gateway.emitState(
        status: 'racing',
        opponent: (
          id: 'them',
          name: 'Kenji Sato',
          ready: true,
          connected: false,
        ),
      );
      await settle();
      expect(bloc.state.opponentReconnecting, isTrue);

      gateway.emitOpponentProgress(5000);
      await settle();

      expect(bloc.state.opponentReconnecting, isFalse);
    });

    test('your own drop mid-solve does not stop your clock', () async {
      await raceToRacing();

      gateway.emitConnection(GatewayConnection.disconnected);
      await settle();
      expect(bloc.state.disconnected, isTrue);

      // Your time is real whether or not the network agrees.
      ticker.emit(const Duration(milliseconds: 7600));
      await settle();
      expect(bloc.state.elapsed, const Duration(milliseconds: 7600));

      // And you can still submit — Redis holds the room, so reconnecting
      // rejoins rather than forfeits.
      bloc.add(const RaceSolveStopped());
      await settle();
      expect(gateway.submittedTimes, <int>[7600]);
    });

    test('a settled race is not reported as disconnected', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 9000));
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();
      gateway.emitResult(result: 'win', yourTime: 9000, oppTime: 10000);
      await settle();

      gateway.emitConnection(GatewayConnection.disconnected);
      await settle();

      expect(bloc.state.disconnected, isFalse);
    });
  });

  group('after the race', () {
    test('dismissing returns a clean lobby', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 9000));
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();
      gateway.emitResult(result: 'win', yourTime: 9000, oppTime: 10000);
      await settle();

      bloc.add(const RaceDismissed());
      await settle();

      expect(bloc.state.phase, RacePhase.idle);
      expect(bloc.state.result, isNull);
      expect(bloc.state.yourTimeMs, isNull);
      expect(bloc.state.scramble, isEmpty);
    });

    test('a rematch re-queues in the same mode', () async {
      await raceToRacing();
      ticker.emit(const Duration(milliseconds: 9000));
      await settle();
      bloc.add(const RaceSolveStopped());
      await settle();
      gateway.emitResult(result: 'loss', yourTime: 12000, oppTime: 10000);
      await settle();

      bloc.add(const RaceRematchRequested());
      await settle();

      expect(bloc.state.phase, RacePhase.searching);
      expect(bloc.state.result, isNull);
      expect(gateway.createdRaces.length, 2);
      expect(gateway.createdRaces.last.mode, 'quick');
    });
  });
}
