import 'package:cubeclash/features/timer/data/local/local_solve_store.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `LocalSolveStore` is the no-backend build's persistence. These prove the two
/// things a relaunch depends on: a solve list survives a save→load round trip
/// intact, and a corrupt preference never throws (it must not stop the app from
/// launching — the same philosophy as `SettingsRepositoryImpl`).
void main() {
  // setMockInitialValues needs the binding; shared_preferences has no real
  // platform channel under `flutter test`.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  const LocalSolveStore store = LocalSolveStore();

  // Local (not UTC) so equality holds after the store's UTC→local round trip:
  // two DateTimes are only `==` when they share the same isUtc flag.
  final DateTime now = DateTime(2026, 7, 22, 10, 30);

  Solve solve({
    required String id,
    String event = '3x3',
    String scramble = "R U R' U'",
    int timeMs = 12340,
    Penalty penalty = Penalty.none,
    int? moveCount,
    int? solvedCount,
    int? attemptedCount,
  }) =>
      Solve(
        id: id,
        event: event,
        scramble: scramble,
        timeMs: timeMs,
        solvedAt: now,
        penalty: penalty,
        moveCount: moveCount,
        solvedCount: solvedCount,
        attemptedCount: attemptedCount,
      );

  group('session round-trip', () {
    test('a mixed list survives save → load intact', () async {
      final List<Solve> solves = <Solve>[
        solve(id: 'a', penalty: Penalty.none),
        solve(id: 'b', timeMs: 15000, penalty: Penalty.plus2),
        solve(id: 'c', timeMs: 20000, penalty: Penalty.dnf),
        // Fewest Moves — a long-form result with a move count and no clock.
        solve(id: 'd', event: '3x3-fmc', timeMs: 0, moveCount: 27),
        // Multi-Blind — solved/attempted, a multi-line scramble.
        solve(
          id: 'e',
          event: '3x3-mbld',
          scramble: 'R U\nF2 B2\nL D',
          timeMs: 3600000,
          solvedCount: 11,
          attemptedCount: 13,
        ),
      ];

      await store.saveSession(solves);

      // Solve is Equatable, so a whole-list compare is exact.
      expect(await store.loadSession(), solves);
    });

    test('an empty session round-trips as empty', () async {
      await store.saveSession(<Solve>[]);
      expect(await store.loadSession(), isEmpty);
    });

    test('significant newlines in a scramble are preserved', () async {
      final Solve mbld = solve(
        id: 'm',
        event: '3x3-mbld',
        scramble: 'a b c\nd e f\ng h i',
        solvedCount: 2,
        attemptedCount: 3,
      );
      await store.saveSession(<Solve>[mbld]);
      expect((await store.loadSession()).single.scramble, mbld.scramble);
    });

    test('the optional long-form fields stay null when absent', () async {
      await store.saveSession(<Solve>[solve(id: 'x')]);
      final Solve loaded = (await store.loadSession()).single;
      expect(loaded.moveCount, isNull);
      expect(loaded.solvedCount, isNull);
      expect(loaded.attemptedCount, isNull);
    });
  });

  group('defensive decode', () {
    test('an absent key loads as empty', () async {
      expect(await store.loadSession(), isEmpty);
    });

    test('non-JSON garbage decodes to empty, never throws', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'timer.session.v1': 'not json at all {{{'},
      );
      expect(await store.loadSession(), isEmpty);
    });

    test('a non-list JSON value decodes to empty', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'timer.session.v1': '{"not":"a list"}'},
      );
      expect(await store.loadSession(), isEmpty);
    });

    test('a list of malformed solves decodes to empty', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'timer.session.v1': '[{"missing":"required fields"}]'},
      );
      expect(await store.loadSession(), isEmpty);
    });
  });

  group('last event', () {
    test('is null before anything is saved', () async {
      expect(await store.loadLastEvent(), isNull);
    });

    test('round-trips a saved event id', () async {
      await store.saveLastEvent('4x4-bld');
      expect(await store.loadLastEvent(), '4x4-bld');
    });

    test('a later save overwrites an earlier one', () async {
      await store.saveLastEvent('2x2');
      await store.saveLastEvent('megaminx');
      expect(await store.loadLastEvent(), 'megaminx');
    });
  });
}
