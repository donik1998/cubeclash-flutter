import 'dart:math';

import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/features/race/data/repositories/fake_tournament_repository.dart';
import 'package:cubeclash/features/race/domain/entities/tournament.dart';
import 'package:cubeclash/features/race/presentation/cubit/tournaments_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2026, 7, 21);

  FakeTournamentRepository repo() =>
      FakeTournamentRepository(random: Random(1), now: now);

  group('FakeTournamentRepository', () {
    test('lists a slate with a live, upcoming and finished tournament',
        () async {
      final List<Tournament> all = (await repo().getTournaments()).valueOrNull!;
      expect(all, isNotEmpty);
      expect(
          all.map((Tournament t) => t.status),
          containsAll(<TournamentStatus>[
            TournamentStatus.live,
            TournamentStatus.upcoming,
            TournamentStatus.finished,
          ]));
    });

    test('a finished tournament has a fully-played bracket', () async {
      final FakeTournamentRepository r = repo();
      final TournamentDetail detail =
          (await r.getTournament('2x2-blitz')).valueOrNull!;

      expect(detail.rounds, hasLength(3)); // QF, SF, Final
      for (final TournamentRound round in detail.rounds) {
        for (final TournamentMatch m in round.matches) {
          expect(m.isPlayed, isTrue, reason: round.name);
          expect(m.winner, anyOf('A', 'B'));
        }
      }
    });

    test('a live tournament leaves the final pending', () async {
      final TournamentDetail detail =
          (await repo().getTournament('weekly-333')).valueOrNull!;
      final TournamentMatch finalMatch = detail.rounds.last.matches.single;
      expect(finalMatch.isPlayed, isFalse);
      // But the players who reached it are known.
      expect(finalMatch.playerA, isNotEmpty);
      expect(finalMatch.playerB, isNotEmpty);
    });

    test('registering bumps the count and marks you in', () async {
      final FakeTournamentRepository r = repo();
      final Tournament before = (await r.getTournaments())
          .valueOrNull!
          .firstWhere((Tournament t) => t.id == 'sub15-sprint');

      expect(await r.register('sub15-sprint'), isA<Ok<void>>());

      final Tournament after = (await r.getTournaments())
          .valueOrNull!
          .firstWhere((Tournament t) => t.id == 'sub15-sprint');
      expect(after.registered, isTrue);
      expect(after.entrants, before.entrants + 1);
    });

    test('an unknown tournament is a clean failure, not a crash', () async {
      expect((await repo().getTournament('nope')).isOk, isFalse);
    });
  });

  group('TournamentsCubit', () {
    test('loads the slate', () async {
      final TournamentsCubit cubit = TournamentsCubit(repository: repo());
      await cubit.load();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.tournaments, isNotEmpty);
    });

    test('register reflects entry in state', () async {
      final TournamentsCubit cubit = TournamentsCubit(repository: repo());
      await cubit.load();
      await cubit.register('sub15-sprint');

      final Tournament t = cubit.state.tournaments
          .firstWhere((Tournament t) => t.id == 'sub15-sprint');
      expect(t.registered, isTrue);
      expect(cubit.state.registeringId, isNull);
    });
  });
}
