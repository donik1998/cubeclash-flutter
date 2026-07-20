import '../../../../core/error/result.dart';
import '../../../../core/network/page.dart';
import '../entities/penalty.dart';
import '../entities/solve.dart';

/// The timer feature's data contract.
///
/// Written against the real endpoints (docs → API Design § Solves) so the
/// interface does not have to change when the backend lands:
///   `POST /solves` · `GET /solves?event=&cursor=` · `PATCH /solves/:id` ·
///   `DELETE /solves/:id`
///
/// **Session vs history.** There is no `sessions` table server-side — a session
/// is a client-side grouping only (docs → Data Model). [watchSession] is
/// therefore a local concern and streams rather than returns: the Timer screen
/// needs the last-solves strip and the running ao5/ao12 to update the instant a
/// solve lands, without a refetch.
abstract class SolveRepository {
  /// The current session's solves, oldest first, pushed on every change.
  Stream<List<Solve>> watchSession();

  /// Records a finished solve.
  ///
  /// [clientId] is a stable client-generated id; the server upserts on
  /// `(user_id, client_id)` so a retried write is idempotent (docs → API
  /// Design § Idempotency).
  ///
  /// [moveCount] / [solvedCount] / [attemptedCount] carry the long-form
  /// events' results and are `null` for the other fifteen — see `Solve`.
  Future<Result<Solve>> addSolve({
    required String event,
    required String scramble,
    required int timeMs,
    required Penalty penalty,
    required DateTime solvedAt,
    required String clientId,
    int? moveCount,
    int? solvedCount,
    int? attemptedCount,
  });

  /// Applies or clears a penalty on an existing solve.
  Future<Result<Solve>> updatePenalty(String id, Penalty penalty);

  /// Soft-deletes a solve.
  Future<Result<void>> deleteSolve(String id);

  /// A page of history, newest first. Pass [cursor] from the previous page's
  /// `nextCursor` to continue.
  Future<Result<Page<Solve>>> getHistory({String event, String? cursor});

  /// Ends the current session. Does **not** delete solves — they stay in
  /// history; only the client-side grouping resets.
  Future<Result<void>> clearSession();
}
