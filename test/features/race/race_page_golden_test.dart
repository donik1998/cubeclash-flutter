import 'package:bloc_test/bloc_test.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/core/realtime/race_gateway.dart';
import 'package:cubeclash/features/race/domain/entities/race_room.dart';
import 'package:cubeclash/features/race/presentation/bloc/race_bloc.dart';
import 'package:cubeclash/features/race/presentation/pages/live_race_page.dart';
import 'package:cubeclash/features/race/presentation/pages/race_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  const Size phone = Size(390, 780);

  const RaceRoom room = RaceRoom(
    id: 'r1',
    status: RaceStatus.readyCheck,
    players: <RacePlayer>[
      RacePlayer(
        userId: 'me',
        displayName: 'You',
        countryCode: 'GB',
        isYou: true,
        ready: true,
      ),
      RacePlayer(
        userId: 'them',
        displayName: 'Kenji Sato',
        countryCode: 'JP',
        progressMs: 5100,
      ),
    ],
  );

  Future<void> goldenFor(
    WidgetTester tester,
    Widget page,
    RaceState state, {
    required String name,
    bool settle = true,
  }) async {
    for (final (String suffix, Brightness brightness) in <(String, Brightness)>[
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      whenListen(bloc, const Stream<RaceState>.empty(), initialState: state);
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
        matchesGoldenFile('goldens/race_${name}_$suffix.png'),
      );
    }
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('lobby — quick match', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const RacePage(),
      const RaceState(),
      name: 'lobby',
    );
  });

  testWidgets('matchmaking modal', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const RacePage(),
      const RaceState(
        phase: RacePhase.searching,
        searchElapsed: Duration(seconds: 14),
      ),
      name: 'matchmaking',
      // The searching pulse repeats forever.
      settle: false,
    );
  });

  // The ready check is part of the full-screen race now, not a lobby state —
  // the frame gives it the race chrome and no nav bar.
  testWidgets('ready room', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const LiveRacePage(),
      const RaceState(
        phase: RacePhase.readyCheck,
        room: room,
        connection: GatewayConnection.connected,
      ),
      name: 'ready_room',
      settle: false,
    );
  });

  testWidgets('countdown', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const LiveRacePage(),
      const RaceState(
        phase: RacePhase.countdown,
        countdown: 3,
        room: room,
        connection: GatewayConnection.connected,
      ),
      name: 'countdown',
    );
  });

  testWidgets('racing', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const LiveRacePage(),
      const RaceState(
        phase: RacePhase.racing,
        scramble: "R U R' U' F2 D B L2 F R' D2 U B2 L F' R2 D' L B U2",
        elapsed: Duration(milliseconds: 7420),
        room: room,
        connection: GatewayConnection.connected,
      ),
      name: 'racing',
      settle: false,
    );
  });

  testWidgets('result — win', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const LiveRacePage(),
      const RaceState(
        phase: RacePhase.settled,
        connection: GatewayConnection.connected,
        scramble: "R U R' U' F2 L' B2 D2 R' F",
        yourTimeMs: 9870,
        room: room,
        result: RaceResult(
          outcome: RaceOutcome.win,
          yourTimeMs: 9870,
          opponentTimeMs: 12340,
          eloDelta: 18,
        ),
      ),
      name: 'result_win',
    );
  });

  testWidgets('result — loss', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const LiveRacePage(),
      const RaceState(
        phase: RacePhase.settled,
        connection: GatewayConnection.connected,
        scramble: "R U R' U' F2 L' B2 D2 R' F",
        yourTimeMs: 13010,
        room: room,
        result: RaceResult(
          outcome: RaceOutcome.loss,
          yourTimeMs: 13010,
          opponentTimeMs: 11500,
          eloDelta: -12,
        ),
      ),
      name: 'result_loss',
    );
  });
}
