import 'dart:math';

import '../../../../core/demo/demo_seed.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/repositories/tournament_repository.dart';

/// Seeded in-memory [TournamentRepository] — the Tournaments tab, demoable with
/// no backend. See [demoTimedEvents] for the same fake-data reasoning.
///
/// Deliberately *demo* data: the UI labels it as such, so no one mistakes the
/// live card for a real competition. Registration mutates in memory so the flow
/// (enter → count bumps → your row shows up) actually works in a walkthrough.
class FakeTournamentRepository implements TournamentRepository {
  FakeTournamentRepository({
    Random? random,
    DateTime? now,
    double readFailureRate = 0,
  })  : _random = random ?? Random(23),
        _now = now ?? DateTime.now(),
        _readFailureRate = readFailureRate {
    _tournaments = _seed();
  }

  final Random _random;
  final DateTime _now;
  final double _readFailureRate;

  late final List<Tournament> _tournaments;

  static const Duration _latency = Duration(milliseconds: 300);

  Future<void> _wait() => Future<void>.delayed(demoLatency(_latency, _random));
  bool get _readFails => _random.nextDouble() < _readFailureRate;
  static const NetworkFailure _networkFailure =
      NetworkFailure('Something went wrong. Pull to retry.');

  @override
  Future<Result<List<Tournament>>> getTournaments() async {
    await _wait();
    if (_readFails) return const Err<List<Tournament>>(_networkFailure);
    return Ok<List<Tournament>>(List<Tournament>.unmodifiable(_tournaments));
  }

  @override
  Future<Result<TournamentDetail>> getTournament(String id) async {
    await _wait();
    if (_readFails) return const Err<TournamentDetail>(_networkFailure);

    final Iterable<Tournament> match =
        _tournaments.where((Tournament t) => t.id == id);
    if (match.isEmpty) {
      return const Err<TournamentDetail>(
        ServerFailure('That tournament could not be found.'),
      );
    }
    final Tournament tournament = match.first;
    return Ok<TournamentDetail>(
      TournamentDetail(tournament: tournament, rounds: _bracketFor(tournament)),
    );
  }

  @override
  Future<Result<void>> register(String id) async {
    await _wait();
    final int i = _tournaments.indexWhere((Tournament t) => t.id == id);
    if (i == -1) {
      return const Err<void>(ServerFailure('That tournament is gone.'));
    }
    final Tournament t = _tournaments[i];
    if (t.registered) return const Ok<void>(null);
    if (t.isFull) {
      return const Err<void>(ServerFailure('This bracket is full.'));
    }
    _tournaments[i] = t.copyWith(registered: true, entrants: t.entrants + 1);
    return const Ok<void>(null);
  }

  // --- Seed data -------------------------------------------------------------

  List<Tournament> _seed() => <Tournament>[
        Tournament(
          id: 'weekly-333',
          name: 'Global Weekly · 3×3',
          event: '3x3',
          status: TournamentStatus.live,
          entrants: 48,
          capacity: 64,
          startsAt: _now.subtract(const Duration(minutes: 20)),
          description:
              'Open 64-player single elimination. New bracket every Sunday.',
        ),
        Tournament(
          id: 'sub15-sprint',
          name: 'Sub-15 Sprint',
          event: '3x3',
          status: TournamentStatus.upcoming,
          entrants: 22,
          capacity: 32,
          startsAt: _now.add(const Duration(hours: 3)),
          description: 'For sub-15 averages only. Fast games, best of three.',
        ),
        Tournament(
          id: 'oh-invitational',
          name: 'One-Handed Invitational',
          event: '3x3-oh',
          status: TournamentStatus.upcoming,
          entrants: 12,
          capacity: 16,
          startsAt: _now.add(const Duration(days: 1, hours: 2)),
          description: 'Sixteen seeds, one hand. Seeded by One-Handed ranking.',
        ),
        Tournament(
          id: '2x2-blitz',
          name: '2×2 Blitz',
          event: '2x2',
          status: TournamentStatus.finished,
          entrants: 32,
          capacity: 32,
          startsAt: _now.subtract(const Duration(days: 2)),
          description: 'Thirty-two players, decided in an afternoon.',
        ),
      ];

  /// An 8-player single-elimination bracket for [t]. A finished tournament has
  /// every match played; a live one has the early rounds done and the final
  /// still pending.
  List<TournamentRound> _bracketFor(Tournament t) {
    final bool finished = t.status == TournamentStatus.finished;
    final List<String> names = <String>[
      'Yuki Tanaka', 'You', 'Ana Silva', 'Lukas Meyer', //
      'Chen Wei', 'Priya Nair', 'Sofia Rossi', 'Omar Haddad',
    ];
    final DemoEventProfile profile =
        demoTimedEvents[t.event] ?? demoTimedEvents['3x3']!;

    int time() {
      final double mean = profile.endMeanMs.toDouble();
      return (mean * (0.85 + _random.nextDouble() * 0.4)).round();
    }

    TournamentMatch played(String a, String b) {
      final int ta = time();
      final int tb = time();
      return TournamentMatch(
        playerA: a,
        playerB: b,
        timeAMs: ta,
        timeBMs: tb,
        winner: ta <= tb ? 'A' : 'B',
      );
    }

    String winnerName(TournamentMatch m) =>
        m.winner == 'A' ? m.playerA : m.playerB;

    // Quarterfinals — always played.
    final List<TournamentMatch> quarters = <TournamentMatch>[
      for (int i = 0; i < 8; i += 2) played(names[i], names[i + 1]),
    ];
    // Semifinals — played in both a live (mid-tournament) and finished bracket.
    final List<TournamentMatch> semis = <TournamentMatch>[
      played(winnerName(quarters[0]), winnerName(quarters[1])),
      played(winnerName(quarters[2]), winnerName(quarters[3])),
    ];
    // Final — pending while live, played when finished.
    final TournamentMatch finalMatch = finished
        ? played(winnerName(semis[0]), winnerName(semis[1]))
        : TournamentMatch(
            playerA: winnerName(semis[0]),
            playerB: winnerName(semis[1]),
          );

    return <TournamentRound>[
      TournamentRound(name: 'Quarterfinals', matches: quarters),
      TournamentRound(name: 'Semifinals', matches: semis),
      TournamentRound(name: 'Final', matches: <TournamentMatch>[finalMatch]),
    ];
  }
}
