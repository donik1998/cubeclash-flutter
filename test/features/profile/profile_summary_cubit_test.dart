import 'package:cubeclash/core/error/failures.dart';
import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/features/profile/domain/entities/profile_summary.dart';
import 'package:cubeclash/features/profile/domain/repositories/profile_summary_repository.dart';
import 'package:cubeclash/features/profile/presentation/cubit/profile_summary_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileSummaryRepository extends Mock
    implements ProfileSummaryRepository {}

const ProfileSummary _summary = ProfileSummary(
  id: 'me',
  displayName: 'Doniyor',
  countryCode: 'GB',
  elo: 1284,
  rank: ProfileRank(
    event: '3x3',
    metric: 'single',
    scope: 'global',
    position: 47,
  ),
  bestSingleMs: 8420,
  bestSingleEvent: '3x3',
  totalSolves: 3204,
  winRate: 0.68,
  wins: 204,
  losses: 96,
  friendCount: 48,
);

void main() {
  late _MockProfileSummaryRepository repository;

  setUp(() {
    repository = _MockProfileSummaryRepository();
  });

  test('starts loading with no summary', () {
    final ProfileSummaryCubit cubit =
        ProfileSummaryCubit(repository: repository);
    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.summary, isNull);
    expect(cubit.state.failure, isNull);
    cubit.close();
  });

  test('load transitions loading → loaded(summary)', () async {
    when(() => repository.getProfileSummary(
          event: any(named: 'event'),
          rankScope: any(named: 'rankScope'),
        )).thenAnswer((_) async => const Ok<ProfileSummary>(_summary));

    final ProfileSummaryCubit cubit =
        ProfileSummaryCubit(repository: repository);
    final List<ProfileSummaryState> seen = <ProfileSummaryState>[];
    cubit.stream.listen(seen.add);

    await cubit.load();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.summary, _summary);
    expect(cubit.state.failure, isNull);
    // A loading emission preceded the loaded one.
    expect(seen.any((ProfileSummaryState s) => s.isLoading), isTrue);
    await cubit.close();
  });

  test('load transitions loading → failure on Err', () async {
    when(() => repository.getProfileSummary(
          event: any(named: 'event'),
          rankScope: any(named: 'rankScope'),
        )).thenAnswer(
      (_) async => const Err<ProfileSummary>(
        NetworkFailure('boom'),
      ),
    );

    final ProfileSummaryCubit cubit =
        ProfileSummaryCubit(repository: repository);

    await cubit.load();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.summary, isNull);
    expect(cubit.state.failure, isA<NetworkFailure>());
    await cubit.close();
  });

  test('retry re-runs the fetch and clears a prior failure', () async {
    int calls = 0;
    when(() => repository.getProfileSummary(
          event: any(named: 'event'),
          rankScope: any(named: 'rankScope'),
        )).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? const Err<ProfileSummary>(NetworkFailure('boom'))
          : const Ok<ProfileSummary>(_summary);
    });

    final ProfileSummaryCubit cubit =
        ProfileSummaryCubit(repository: repository);

    await cubit.load();
    expect(cubit.state.failure, isA<NetworkFailure>());

    await cubit.retry();
    expect(cubit.state.failure, isNull);
    expect(cubit.state.summary, _summary);
    expect(calls, 2);
    await cubit.close();
  });
}
