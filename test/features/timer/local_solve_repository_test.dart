import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/features/timer/data/local/local_solve_store.dart';
import 'package:cubeclash/features/timer/data/repositories/local_solve_repository.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The point of `LocalSolveRepository` is that a **fresh instance** — the stand
/// in for a relaunched process — sees everything a previous instance wrote. So
/// every test mutates through one repository, drops it, and asserts on a second
/// one reading the same (mocked) SharedPreferences.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  const LocalSolveStore store = LocalSolveStore();

  // A distinct solvedAt per solve so newest-first ordering is unambiguous.
  DateTime at(int minute) => DateTime(2026, 7, 22, 10, minute);

  Future<Solve> add(
    LocalSolveRepository repo, {
    required String id,
    String event = '3x3',
    int timeMs = 10000,
    int minute = 0,
    Penalty penalty = Penalty.none,
  }) async {
    final Result<Solve> res = await repo.addSolve(
      event: event,
      scramble: "R U R' U'",
      timeMs: timeMs,
      penalty: penalty,
      solvedAt: at(minute),
      clientId: id,
    );
    return (res as Ok<Solve>).value;
  }

  Future<List<Solve>> session(LocalSolveRepository repo) =>
      repo.watchSession().first;

  test('a solve added in one instance is present after a relaunch', () async {
    final LocalSolveRepository first = LocalSolveRepository(store);
    await add(first, id: 'a');
    await first.dispose();

    final LocalSolveRepository relaunched = LocalSolveRepository(store);
    expect(await session(relaunched), hasLength(1));
    expect((await session(relaunched)).single.id, 'a');
    await relaunched.dispose();
  });

  test('an edited penalty persists across a relaunch', () async {
    final LocalSolveRepository first = LocalSolveRepository(store);
    final Solve solve = await add(first, id: 'a');
    final Result<Solve> updated =
        await first.updatePenalty(solve.id, Penalty.plus2);
    expect(updated, isA<Ok<Solve>>());
    await first.dispose();

    final LocalSolveRepository relaunched = LocalSolveRepository(store);
    expect((await session(relaunched)).single.penalty, Penalty.plus2);
    await relaunched.dispose();
  });

  test('a delete persists across a relaunch', () async {
    final LocalSolveRepository first = LocalSolveRepository(store);
    await add(first, id: 'a', minute: 0);
    await add(first, id: 'b', minute: 1);
    await first.deleteSolve('a');
    await first.dispose();

    final LocalSolveRepository relaunched = LocalSolveRepository(store);
    final List<Solve> solves = await session(relaunched);
    expect(solves.map((Solve s) => s.id), <String>['b']);
    await relaunched.dispose();
  });

  test('clearSession empties the persisted session', () async {
    final LocalSolveRepository first = LocalSolveRepository(store);
    await add(first, id: 'a');
    await add(first, id: 'b', minute: 1);
    await first.clearSession();
    await first.dispose();

    final LocalSolveRepository relaunched = LocalSolveRepository(store);
    expect(await session(relaunched), isEmpty);
    await relaunched.dispose();
  });

  test('deleting a solve that is gone returns an error', () async {
    final LocalSolveRepository repo = LocalSolveRepository(store);
    final Result<void> res = await repo.deleteSolve('nope');
    expect(res, isA<Err<void>>());
    await repo.dispose();
  });

  group('getHistory', () {
    test('returns the event\'s solves newest first', () async {
      final LocalSolveRepository repo = LocalSolveRepository(store);
      await add(repo, id: 'old', minute: 0);
      await add(repo, id: 'mid', minute: 5);
      await add(repo, id: 'new', minute: 9);

      final Result<dynamic> page = await repo.getHistory();
      final List<Solve> items = (page as Ok).value.items as List<Solve>;
      expect(items.map((Solve s) => s.id), <String>['new', 'mid', 'old']);
      await repo.dispose();
    });

    test('filters by event', () async {
      final LocalSolveRepository repo = LocalSolveRepository(store);
      await add(repo, id: 'a', event: '3x3', minute: 0);
      await add(repo, id: 'b', event: '4x4', minute: 1);

      final Result<dynamic> page = await repo.getHistory(event: '4x4');
      final List<Solve> items = (page as Ok).value.items as List<Solve>;
      expect(items.map((Solve s) => s.id), <String>['b']);
      await repo.dispose();
    });
  });
}
