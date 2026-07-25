import '../../../../core/error/result.dart';
import '../entities/lobby_summary.dart';

/// The lobby's summary data — `GET /race/summary` (proposed).
///
/// A dedicated endpoint on purpose: the header's Elo pill, the Quick Match
/// stats row and the rivals list are one server-owned payload, not three fields
/// stitched from Profile, Stats and the race gateway on the client.
abstract class RaceLobbyRepository {
  Future<Result<LobbySummary>> summary();
}
