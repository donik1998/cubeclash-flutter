import 'dart:math';

import '../../../../core/demo/demo_seed.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/profile_summary.dart';
import '../../domain/repositories/profile_summary_repository.dart';

/// Seeded in-memory [ProfileSummaryRepository].
///
/// Internally consistent with the app's existing demo identity: the same
/// `Doniyor` / `GB` / elo `1284` that [FakeProfileRepository] uses, the same
/// `best 8.42` headline the Stats demo shows, and the rank-47 slot the fake
/// leaderboard embeds the user at.
class FakeProfileSummaryRepository implements ProfileSummaryRepository {
  FakeProfileSummaryRepository({Random? random, double readFailureRate = 0})
      : _random = random ?? Random(13),
        _readFailureRate = readFailureRate;

  final Random _random;

  /// How often a read pretends the network failed, so the error state is
  /// reachable in a demo. Defaults to 0; wire a small value in DI to show it.
  final double _readFailureRate;

  static const Duration _latency = Duration(milliseconds: 240);

  Future<void> _wait() => Future<void>.delayed(demoLatency(_latency, _random));

  bool get _readFails => _random.nextDouble() < _readFailureRate;

  @override
  Future<Result<ProfileSummary>> getProfileSummary({
    String event = '3x3',
    String rankScope = 'global',
  }) async {
    await _wait();
    if (_readFails) {
      return const Err<ProfileSummary>(
        NetworkFailure('Something went wrong. Pull to retry.'),
      );
    }

    // wins/losses reconcile with win_rate: 204 / (204 + 96) == 0.68 exactly,
    // the screenshot's figure. Kept consistent so the ratio and its supporting
    // counts never contradict.
    return const Ok<ProfileSummary>(
      ProfileSummary(
        id: 'me',
        displayName: 'Doniyor',
        countryCode: 'GB',
        elo: 1284,
        rank: ProfileRank(
          event: '3x3',
          metric: 'single',
          scope: 'global',
          // The fake leaderboard embeds the current user at rank 47.
          position: 47,
        ),
        // Matches the Stats demo's `best 8.42` headline.
        bestSingleMs: 8420,
        bestSingleEvent: '3x3',
        totalSolves: 3204,
        winRate: 0.68,
        wins: 204,
        losses: 96,
        friendCount: 48,
      ),
    );
  }
}
