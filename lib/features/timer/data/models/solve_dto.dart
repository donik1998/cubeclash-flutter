import '../../domain/entities/penalty.dart';
import '../../domain/entities/solve.dart';

/// Wire ↔ domain mapping for a solve.
///
/// Field names mirror the `solves` table / `POST /solves` body (docs → API
/// Design, Data Model): `snake_case` throughout.
///
/// **Decisions the docs leave open**, fixed here so client and server can't
/// silently disagree:
///   * timestamps are **ISO 8601 with an explicit UTC offset** (`solved_at`,
///     `updated_at`). The vault never states a format; ISO 8601 is the only
///     choice that survives a timezone change on the device.
///   * the `penalty` enum goes over the wire as `none` | `plus2` | `dnf`,
///     matching the Postgres enum exactly rather than the display form (`+2`).
///
/// Note `is_pb` is **read-only** here. It is server-owned; the client parses it
/// for display and never sends or derives it.
class SolveDto {
  const SolveDto._();

  static Solve fromJson(Map<String, dynamic> json) => Solve(
        id: json['id'] as String,
        event: json['event'] as String? ?? '3x3',
        scramble: json['scramble'] as String? ?? '',
        timeMs: (json['time_ms'] as num).toInt(),
        solvedAt: DateTime.parse(json['solved_at'] as String).toLocal(),
        penalty: penaltyFromWire(json['penalty'] as String?),
        // Long-form events only, and absent for the other fifteen — hence
        // nullable rather than defaulted. A 3×3 solve carrying `move_count: 0`
        // would be a claim, not a blank.
        moveCount: (json['move_count'] as num?)?.toInt(),
        solvedCount: (json['solved_count'] as num?)?.toInt(),
        attemptedCount: (json['attempted_count'] as num?)?.toInt(),
      );

  /// Body for `POST /solves`.
  ///
  /// [clientId] makes the write idempotent — the server upserts on
  /// `(user_id, client_id)`, so a retry after a flaky connection cannot create
  /// a duplicate solve.
  static Map<String, dynamic> toCreateJson({
    required String event,
    required String scramble,
    required int timeMs,
    required Penalty penalty,
    required DateTime solvedAt,
    required String clientId,
    int? moveCount,
    int? solvedCount,
    int? attemptedCount,
  }) =>
      <String, dynamic>{
        'event': event,
        // Stays a plain string, newline-separated where the event's notation
        // has significant line breaks (Megaminx, Multi-Blind). See `Scramble`
        // — notation is a client display concern, so the wire format did not
        // have to change and the backend does not have to know about it. The
        // one new guarantee is that `\n` is significant and must round-trip.
        'scramble': scramble,
        // The MVP scrambler is random-move, not a WCA random-state solver.
        // The server records which, so stats can be segmented by source later.
        'scramble_source': 'random',
        'time_ms': timeMs,
        'penalty': penaltyToWire(penalty),
        'solved_at': solvedAt.toUtc().toIso8601String(),
        'client_id': clientId,
        // Omitted entirely for the fifteen events that have no such result,
        // rather than sent as null — the column is genuinely inapplicable, and
        // an absent key says that where an explicit null does not.
        if (moveCount != null) 'move_count': moveCount,
        if (solvedCount != null) 'solved_count': solvedCount,
        if (attemptedCount != null) 'attempted_count': attemptedCount,
      };

  static Penalty penaltyFromWire(String? wire) => switch (wire) {
        'plus2' => Penalty.plus2,
        'dnf' => Penalty.dnf,
        _ => Penalty.none,
      };

  static String penaltyToWire(Penalty penalty) => switch (penalty) {
        Penalty.none => 'none',
        Penalty.plus2 => 'plus2',
        Penalty.dnf => 'dnf',
      };
}
