import '../../../../core/error/result.dart';
import '../entities/tournament.dart';

/// Tournament listing, detail and registration.
///
/// Endpoints (proposed; the vault lists tournaments under roadmap): `GET
/// /tournaments`, `GET /tournaments/:id`, `POST /tournaments/:id/register`.
/// Ships a fake so the Tournaments tab is a working, demoable feature with no
/// backend, and a real impl written against the proposed contract.
abstract class TournamentRepository {
  Future<Result<List<Tournament>>> getTournaments();

  Future<Result<TournamentDetail>> getTournament(String id);

  /// Enters the signed-in user. The server owns capacity and seeding; the fake
  /// just flips `registered` and bumps the count.
  Future<Result<void>> register(String id);
}
