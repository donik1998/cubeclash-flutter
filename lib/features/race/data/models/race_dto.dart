import '../../domain/entities/race_room.dart';

/// Decodes the `/race` namespace's payloads into domain entities.
///
/// Field names follow docs → Real-time Race Protocol and the `race_participants`
/// table. The protocol doc gives event names but **no payload types**, so the
/// decoding here is deliberately defensive: every field has a fallback, and a
/// malformed message degrades the UI rather than throwing inside a stream
/// listener (where an exception would kill the subscription and freeze the
/// race).
class RaceDto {
  const RaceDto._();

  static RaceRoom roomFromJson(Map<String, dynamic> json) {
    final List<dynamic> rawPlayers =
        (json['players'] as List<dynamic>?) ?? <dynamic>[];

    return RaceRoom(
      id: json['race_id'] as String? ?? json['id'] as String? ?? '',
      status: RaceStatus.fromWire(json['status'] as String?),
      mode: _modeFromWire(json['mode'] as String?),
      event: json['event'] as String? ?? '3x3',
      code: json['code'] as String?,
      players: <RacePlayer>[
        for (final dynamic p in rawPlayers) playerFromJson(_asMap(p)),
      ],
    );
  }

  static RacePlayer playerFromJson(Map<String, dynamic> json) => RacePlayer(
        userId: json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? 'Opponent',
        countryCode: json['country'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        ready: json['ready'] as bool? ?? false,
        isYou: json['is_me'] as bool? ?? false,
        connected: json['connected'] as bool? ?? true,
        progressMs: _int(json['running_ms']),
        finalTimeMs: _int(json['time_ms']),
      );

  static RaceResult resultFromJson(Map<String, dynamic> json) {
    final bool yourDnf = json['your_dnf'] as bool? ?? false;
    final bool opponentDnf = json['opponent_dnf'] as bool? ?? false;

    return RaceResult(
      outcome: RaceOutcome.fromWire(json['result'] as String?),
      yourTimeMs: _int(json['your_time']),
      opponentTimeMs: _int(json['opp_time']),
      eloDelta: _int(json['elo_delta']),
      yourDnf: yourDnf,
      opponentDnf: opponentDnf,
      opponentLeft: json['opponent_left'] as bool? ?? false,
    );
  }

  static RaceMode _modeFromWire(String? wire) => switch (wire) {
        'private' => RaceMode.private,
        'tournament' => RaceMode.tournament,
        _ => RaceMode.quick,
      };

  static Map<String, dynamic> _asMap(dynamic d) =>
      d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};

  static int? _int(dynamic v) => v is num ? v.toInt() : null;
}
