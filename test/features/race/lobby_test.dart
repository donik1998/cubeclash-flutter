import 'dart:math';

import 'package:cubeclash/features/race/data/repositories/fake_race_lobby_repository.dart';
import 'package:cubeclash/features/race/domain/entities/lobby_summary.dart';
import 'package:cubeclash/features/race/presentation/cubit/lobby_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lobby summary', () {
    test('the fake supplies Elo, rank, win rate and rivals', () async {
      final LobbySummary s =
          (await FakeRaceLobbyRepository(random: Random(1)).summary())
              .valueOrNull!;
      expect(s.elo, greaterThan(0));
      expect(s.globalRank, greaterThan(0));
      expect(s.winRate, isNotNull);
      expect(s.recentRivals, isNotEmpty);
    });

    test('win rate is wins over total, or null with no races', () {
      const LobbySummary played =
          LobbySummary(elo: 1200, globalRank: 5, wins: 3, losses: 1);
      expect(played.winRate, 75);

      const LobbySummary none =
          LobbySummary(elo: 1000, globalRank: 9, wins: 0, losses: 0);
      expect(none.winRate, isNull);
    });

    test('LobbyCubit loads the summary', () async {
      final LobbyCubit cubit =
          LobbyCubit(repository: FakeRaceLobbyRepository(random: Random(2)));
      await cubit.load();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.summary, isNotNull);
    });
  });
}
