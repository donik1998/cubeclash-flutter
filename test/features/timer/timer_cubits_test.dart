import 'package:cubeclash/core/analytics/analytics_service.dart';
import 'package:cubeclash/core/error/failures.dart';
import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/core/network/page.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:cubeclash/features/timer/domain/repositories/solve_repository.dart';
import 'package:cubeclash/features/timer/presentation/cubit/history_cubit.dart';
import 'package:cubeclash/features/timer/presentation/cubit/solve_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSolveRepository extends Mock implements SolveRepository {}

void main() {
  late _MockSolveRepository repository;

  Solve solveOf({
    required String id,
    int timeMs = 12000,
    Penalty penalty = Penalty.none,
    DateTime? solvedAt,
  }) =>
      Solve(
        id: id,
        event: '3x3',
        scramble: 'R U R\'',
        timeMs: timeMs,
        solvedAt: solvedAt ?? DateTime(2026, 7, 19, 10),
        penalty: penalty,
      );

  setUpAll(() => registerFallbackValue(Penalty.none));

  setUp(() {
    repository = _MockSolveRepository();
  });

  group('HistoryCubit', () {
    test('loads the first page', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(
            items: <Solve>[solveOf(id: 'a'), solveOf(id: 'b')],
            nextCursor: '2',
          ),
        ),
      );

      final HistoryCubit cubit = HistoryCubit(repository: repository);
      await cubit.load();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.solves, hasLength(2));
      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.isEmpty, isFalse);
    });

    test('an empty first page is the empty state, not an error', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => const Ok<Page<Solve>>(Page<Solve>(items: <Solve>[])),
      );

      final HistoryCubit cubit = HistoryCubit(repository: repository);
      await cubit.load();

      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.hasMore, isFalse);
    });

    test('a failed first load surfaces the failure', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => const Err<Page<Solve>>(NetworkFailure('offline')),
      );

      final HistoryCubit cubit = HistoryCubit(repository: repository);
      await cubit.load();

      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.solves, isEmpty);
      expect(cubit.state.isLoading, isFalse);
    });

    test('loadMore appends and clears the cursor at the end', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: null,
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(items: <Solve>[solveOf(id: 'a')], nextCursor: '1'),
        ),
      );
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: '1',
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(Page<Solve>(items: <Solve>[
          solveOf(id: 'b'),
        ])),
      );

      final HistoryCubit cubit = HistoryCubit(repository: repository);
      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.solves.map((Solve s) => s.id), <String>['a', 'b']);
      expect(cubit.state.hasMore, isFalse);
    });

    test('loadMore is a no-op once the cursor is exhausted', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(items: <Solve>[solveOf(id: 'a')]),
        ),
      );

      final HistoryCubit cubit = HistoryCubit(repository: repository);
      await cubit.load();
      await cubit.loadMore();
      await cubit.loadMore();

      // Only the initial load hit the repository.
      verify(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: any(named: 'cursor'),
          )).called(1);
    });

    test('a failed page keeps what is already loaded', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: null,
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(items: <Solve>[solveOf(id: 'a')], nextCursor: '1'),
        ),
      );
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: '1',
          )).thenAnswer(
        (_) async => const Err<Page<Solve>>(NetworkFailure('offline')),
      );

      final HistoryCubit cubit = HistoryCubit(repository: repository);
      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.solves, hasLength(1));
      expect(cubit.state.failure, isA<NetworkFailure>());
    });

    test('groups solves by calendar day, newest day first', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(
            items: <Solve>[
              solveOf(id: 'a', solvedAt: DateTime(2026, 7, 19, 14)),
              solveOf(id: 'b', solvedAt: DateTime(2026, 7, 19, 9)),
              solveOf(id: 'c', solvedAt: DateTime(2026, 7, 17, 9)),
            ],
          ),
        ),
      );

      final HistoryCubit cubit = HistoryCubit(repository: repository);
      await cubit.load();

      final List<({DateTime day, List<Solve> solves})> groups =
          cubit.state.byDay;
      expect(groups, hasLength(2));
      expect(groups.first.day, DateTime(2026, 7, 19));
      expect(groups.first.solves, hasLength(2));
      expect(groups.last.day, DateTime(2026, 7, 17));
    });

    test('statsFor reads the newest-first list in solve order', () {
      final HistoryCubit cubit = HistoryCubit(repository: repository);

      // Newest first: 14, 13, 12, 11, 10 — i.e. chronologically 10 … 14.
      final List<Solve> newestFirst = <Solve>[
        for (int i = 4; i >= 0; i--)
          solveOf(id: 's$i', timeMs: 10000 + i * 1000),
      ];

      final ({int? ao12, int? ao5, int? best}) stats =
          cubit.statsFor(newestFirst);

      expect(stats.best, 10000);
      // ao5 trims 10 and 14, means 11/12/13.
      expect(stats.ao5, 12000);
      expect(stats.ao12, isNull, reason: 'needs 12 solves');
    });
  });

  group('SolveDetailCubit', () {
    SolveDetailCubit build() => SolveDetailCubit(
          repository: repository,
          analytics: const NoopAnalytics(),
        );

    test('finds a solve on a later page', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: null,
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(items: <Solve>[solveOf(id: 'a')], nextCursor: '1'),
        ),
      );
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: '1',
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(items: <Solve>[solveOf(id: 'target', timeMs: 9990)]),
        ),
      );

      final SolveDetailCubit cubit = build();
      await cubit.load('target');

      expect(cubit.state.solve?.id, 'target');
      expect(cubit.state.isLoading, isFalse);
    });

    test('an unknown id resolves to not-found rather than hanging', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(items: <Solve>[solveOf(id: 'a')]),
        ),
      );

      final SolveDetailCubit cubit = build();
      await cubit.load('missing');

      expect(cubit.state.solve, isNull);
      expect(cubit.state.isLoading, isFalse);
    });

    test('penalty edits roll back when the write fails', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(items: <Solve>[solveOf(id: 'a')]),
        ),
      );
      when(() => repository.updatePenalty(any(), any())).thenAnswer(
        (_) async => const Err<Solve>(ServerFailure('nope')),
      );

      final SolveDetailCubit cubit = build();
      await cubit.load('a');
      await cubit.changePenalty(Penalty.dnf);

      expect(cubit.state.solve?.penalty, Penalty.none);
      expect(cubit.state.failure, isA<ServerFailure>());
    });

    test('a successful delete signals the view to pop', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(items: <Solve>[solveOf(id: 'a')]),
        ),
      );
      when(() => repository.deleteSolve(any()))
          .thenAnswer((_) async => const Ok<void>(null));

      final SolveDetailCubit cubit = build();
      await cubit.load('a');
      await cubit.delete();

      expect(cubit.state.deleted, isTrue);
    });

    test('a failed delete keeps the user on the screen', () async {
      when(() => repository.getHistory(
            event: any(named: 'event'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => Ok<Page<Solve>>(
          Page<Solve>(items: <Solve>[solveOf(id: 'a')]),
        ),
      );
      when(() => repository.deleteSolve(any()))
          .thenAnswer((_) async => const Err<void>(NetworkFailure('offline')));

      final SolveDetailCubit cubit = build();
      await cubit.load('a');
      await cubit.delete();

      expect(cubit.state.deleted, isFalse);
      expect(cubit.state.failure, isA<NetworkFailure>());
    });
  });
}
