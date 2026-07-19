import '../../../../core/error/result.dart';
import '../entities/leaderboard_entry.dart';
import '../entities/player_stats.dart';

/// Stats and leaderboards.
///
/// Endpoints (docs → API Design):
///   `GET /stats?event=3x3`
///   `GET /leaderboard?event=&metric=single|ao5&scope=global|friends|country&cursor=`
///   `GET /users/:id`
///
/// Everything here is **server-computed**. There is no local fallback and no
/// client-side ranking — see the notes on [PlayerStats] and [LeaderboardEntry].
abstract class StatsRepository {
  Future<Result<PlayerStats>> getStats({String event});

  Future<Result<Leaderboard>> getLeaderboard({
    String event,
    LeaderboardMetric metric,
    LeaderboardScope scope,
    String? cursor,
  });

  Future<Result<PlayerProfile>> getPlayer(String userId);
}
