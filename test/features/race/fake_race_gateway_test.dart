import 'dart:math';

import 'package:cubeclash/features/race/data/fake_race_gateway.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// The opponent block of the latest `race:state`, or null before one appears.
Map<String, dynamic>? _opponentOf(Map<String, dynamic> state) {
  final List<dynamic> players = state['players'] as List<dynamic>;
  for (final dynamic p in players) {
    final Map<String, dynamic> player = p as Map<String, dynamic>;
    if (player['is_me'] == false) return player;
  }
  return null;
}

/// Runs a whole quick-match race to settlement, collecting every `race:state`.
List<Map<String, dynamic>> _runRace({
  required double dropChance,
  required int seed,
}) {
  final List<Map<String, dynamic>> states = <Map<String, dynamic>>[];
  fakeAsync((FakeAsync async) {
    final FakeRaceGateway gateway = FakeRaceGateway(
      random: Random(seed),
      opponentDropChance: dropChance,
    );
    gateway.onState.listen(states.add);

    gateway.connect();
    gateway.createRace(mode: 'quick', event: '3x3');
    async.elapse(const Duration(seconds: 5)); // matchmaking + opponent readies
    gateway.ready();
    async.elapse(const Duration(seconds: 4)); // countdown, into the solve
    gateway.solveStop(8000);
    async.elapse(const Duration(seconds: 40)); // opponent finishes, settles

    gateway.dispose();
  });
  return states;
}

void main() {
  group('FakeRaceGateway opponent roster', () {
    test('picks a named opponent from the roster', () {
      final List<Map<String, dynamic>> states =
          _runRace(dropChance: 0, seed: 3);
      final Map<String, dynamic>? opp =
          states.map(_opponentOf).whereType<Map<String, dynamic>>().lastOrNull;

      expect(opp, isNotNull);
      expect((opp!['display_name'] as String), isNotEmpty);
      expect((opp['country'] as String).length, 2);
    });

    test('is not always the same face across races', () {
      final Set<String> names = <String>{};
      for (int seed = 0; seed < 8; seed++) {
        final List<Map<String, dynamic>> states =
            _runRace(dropChance: 0, seed: seed);
        final Map<String, dynamic>? opp = states
            .map(_opponentOf)
            .whereType<Map<String, dynamic>>()
            .lastOrNull;
        if (opp != null) names.add(opp['display_name'] as String);
      }
      expect(names.length, greaterThan(1),
          reason: 'the roster should surface more than one opponent');
    });
  });

  group('FakeRaceGateway connection blip', () {
    bool sawDisconnect(List<Map<String, dynamic>> states) => states
        .map(_opponentOf)
        .whereType<Map<String, dynamic>>()
        .any((Map<String, dynamic> o) => o['connected'] == false);

    bool sawReconnectAfterDrop(List<Map<String, dynamic>> states) {
      bool dropped = false;
      for (final Map<String, dynamic> s in states) {
        final Map<String, dynamic>? o = _opponentOf(s);
        if (o == null) continue;
        if (o['connected'] == false) dropped = true;
        if (dropped && o['connected'] == true) return true;
      }
      return false;
    }

    test('drops and then restores the opponent when forced on', () {
      final List<Map<String, dynamic>> states =
          _runRace(dropChance: 1, seed: 1);
      expect(sawDisconnect(states), isTrue);
      expect(sawReconnectAfterDrop(states), isTrue,
          reason: 'a drop must be followed by a reconnect');
    });

    test('never disconnects when the chance is zero', () {
      final List<Map<String, dynamic>> states =
          _runRace(dropChance: 0, seed: 1);
      expect(sawDisconnect(states), isFalse);
    });
  });

  test('still reaches a result — the blip does not strand the race', () {
    fakeAsync((FakeAsync async) {
      final FakeRaceGateway gateway = FakeRaceGateway(
        random: Random(2),
        opponentDropChance: 1,
      );
      final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
      gateway.onResult.listen(results.add);

      gateway.connect();
      gateway.createRace(mode: 'quick', event: '3x3');
      async.elapse(const Duration(seconds: 5));
      gateway.ready();
      async.elapse(const Duration(seconds: 4));
      gateway.solveStop(8000);
      async.elapse(const Duration(seconds: 40));

      expect(results, hasLength(1));
      expect(results.single['result'], anyOf('win', 'loss'));

      gateway.dispose();
    });
  });
}
