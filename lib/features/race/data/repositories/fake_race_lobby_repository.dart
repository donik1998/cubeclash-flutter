import 'dart:math';

import '../../../../core/demo/demo_seed.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/lobby_summary.dart';
import '../../domain/repositories/race_lobby_repository.dart';

/// Seeded [RaceLobbyRepository] — supplies the lobby's Elo pill, stats row and
/// rivals list so those frame elements are real in the demo.
class FakeRaceLobbyRepository implements RaceLobbyRepository {
  FakeRaceLobbyRepository({Random? random, double readFailureRate = 0})
      : _random = random ?? Random(29),
        _readFailureRate = readFailureRate;

  final Random _random;
  final double _readFailureRate;

  static const Duration _latency = Duration(milliseconds: 240);

  @override
  Future<Result<LobbySummary>> summary() async {
    await Future<void>.delayed(demoLatency(_latency, _random));
    if (_random.nextDouble() < _readFailureRate) {
      return const Err<LobbySummary>(
        NetworkFailure('Something went wrong. Pull to retry.'),
      );
    }

    return const Ok<LobbySummary>(
      LobbySummary(
        elo: 1284,
        globalRank: 1204,
        wins: 63,
        losses: 41,
        bestSingleMs: 8420,
        ao5Ms: 10960,
        recentRivals: <Rival>[
          Rival(
            userId: 'u1',
            displayName: 'Yuki Tanaka',
            wins: 2,
            losses: 3,
            countryCode: 'JP',
          ),
          Rival(
            userId: 'u5',
            displayName: 'Lukas Meyer',
            wins: 4,
            losses: 1,
            countryCode: 'DE',
          ),
          Rival(
            userId: 'u2',
            displayName: 'Ana Silva',
            wins: 1,
            losses: 1,
            countryCode: 'BR',
          ),
        ],
      ),
    );
  }
}
