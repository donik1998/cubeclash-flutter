import 'package:equatable/equatable.dart';

/// The room lifecycle, exactly as the server drives it.
///
/// `waiting → readyCheck → countdown → racing → settled`
///
/// Source: docs → `02 System Design/Real-time Race Protocol`. Note the vault's
/// `races.status` DB enum omits `ready-check` — that step lives only in Redis
/// room state and never persists, which is why it appears here but not in the
/// data model.
enum RaceStatus {
  /// Waiting for an opponent (quick match) or for someone to join the code.
  waiting,

  /// Both players present, confirming ready.
  readyCheck,

  /// 3-2-1-GO. The scramble is revealed to both at the same instant.
  countdown,

  /// Solving.
  racing,

  /// Server has validated, ranked, and broadcast the result.
  settled;

  static RaceStatus fromWire(String? wire) => switch (wire) {
        'ready-check' || 'ready_check' || 'readyCheck' => RaceStatus.readyCheck,
        'countdown' => RaceStatus.countdown,
        'racing' => RaceStatus.racing,
        'settled' => RaceStatus.settled,
        _ => RaceStatus.waiting,
      };
}

enum RaceMode {
  quick,
  private,
  tournament;

  String get wire => name;
}

/// How a race ended for one participant. Mirrors the `result` enum on
/// `race_participants`.
enum RaceOutcome {
  win,
  loss,
  dnf,
  left;

  static RaceOutcome fromWire(String? wire) => switch (wire) {
        'win' => RaceOutcome.win,
        'dnf' => RaceOutcome.dnf,
        'left' => RaceOutcome.left,
        _ => RaceOutcome.loss,
      };
}

/// One participant.
class RacePlayer extends Equatable {
  const RacePlayer({
    required this.userId,
    required this.displayName,
    this.countryCode,
    this.avatarUrl,
    this.ready = false,
    this.isYou = false,
    this.connected = true,
    this.progressMs,
    this.finalTimeMs,
  });

  final String userId;
  final String displayName;
  final String? countryCode;
  final String? avatarUrl;
  final bool ready;
  final bool isYou;

  /// False while they're inside the disconnect grace window.
  final bool connected;

  /// Live running time from `race:opponent_progress`. Null before they start.
  final int? progressMs;

  /// Set once they've submitted.
  final int? finalTimeMs;

  bool get hasFinished => finalTimeMs != null;

  RacePlayer copyWith({
    bool? ready,
    bool? connected,
    int? progressMs,
    int? finalTimeMs,
  }) =>
      RacePlayer(
        userId: userId,
        displayName: displayName,
        countryCode: countryCode,
        avatarUrl: avatarUrl,
        ready: ready ?? this.ready,
        isYou: isYou,
        connected: connected ?? this.connected,
        progressMs: progressMs ?? this.progressMs,
        finalTimeMs: finalTimeMs ?? this.finalTimeMs,
      );

  @override
  List<Object?> get props => <Object?>[
        userId,
        displayName,
        countryCode,
        avatarUrl,
        ready,
        isYou,
        connected,
        progressMs,
        finalTimeMs,
      ];
}

/// Server-held room state, as delivered by `race:state`.
class RaceRoom extends Equatable {
  const RaceRoom({
    required this.id,
    required this.status,
    required this.players,
    this.mode = RaceMode.quick,
    this.event = '3x3',
    this.code,
  });

  final String id;
  final RaceStatus status;
  final List<RacePlayer> players;
  final RaceMode mode;
  final String event;

  /// Shareable invite code, for a private room.
  final String? code;

  RacePlayer? get you => _firstWhere((RacePlayer p) => p.isYou);

  RacePlayer? get opponent => _firstWhere((RacePlayer p) => !p.isYou);

  RacePlayer? _firstWhere(bool Function(RacePlayer) test) {
    for (final RacePlayer p in players) {
      if (test(p)) return p;
    }
    return null;
  }

  bool get isFull => players.length >= 2;

  /// Both confirmed — the server advances to countdown on this.
  bool get everyoneReady => isFull && players.every((RacePlayer p) => p.ready);

  RaceRoom copyWith({
    RaceStatus? status,
    List<RacePlayer>? players,
    String? code,
  }) =>
      RaceRoom(
        id: id,
        status: status ?? this.status,
        players: players ?? this.players,
        mode: mode,
        event: event,
        code: code ?? this.code,
      );

  /// Replaces one player by id, leaving the rest untouched.
  RaceRoom withPlayer(String userId, RacePlayer Function(RacePlayer) update) =>
      copyWith(
        players: players
            .map((RacePlayer p) => p.userId == userId ? update(p) : p)
            .toList(),
      );

  @override
  List<Object?> get props => <Object?>[id, status, players, mode, event, code];
}

/// The settled outcome, from `race:result`.
///
/// **Entirely server-decided.** The client never compares two times and infers
/// a winner — it renders what it is told. That is what makes the race
/// trustworthy, and [eloDelta] is server-supplied for the same reason.
class RaceResult extends Equatable {
  const RaceResult({
    required this.outcome,
    this.yourTimeMs,
    this.opponentTimeMs,
    this.eloDelta,
    this.yourDnf = false,
    this.opponentDnf = false,
    this.opponentLeft = false,
  });

  final RaceOutcome outcome;
  final int? yourTimeMs;
  final int? opponentTimeMs;

  /// Signed rating change, e.g. `+18` or `-14`. Null if unranked.
  final int? eloDelta;

  final bool yourDnf;
  final bool opponentDnf;

  /// The opponent disconnected past the grace window.
  final bool opponentLeft;

  bool get isWin => outcome == RaceOutcome.win;

  /// Margin in ms, when both finished cleanly.
  int? get deltaMs {
    final int? mine = yourTimeMs;
    final int? theirs = opponentTimeMs;
    if (mine == null || theirs == null || yourDnf || opponentDnf) return null;
    return (mine - theirs).abs();
  }

  @override
  List<Object?> get props => <Object?>[
        outcome,
        yourTimeMs,
        opponentTimeMs,
        eloDelta,
        yourDnf,
        opponentDnf,
        opponentLeft,
      ];
}
