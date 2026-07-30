import 'dart:math';

import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/features/profile/data/repositories/fake_profile_summary_repository.dart';
import 'package:cubeclash/features/profile/domain/entities/profile_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeProfileSummaryRepository', () {
    test('nominal returns Ok with the demo identity', () async {
      final FakeProfileSummaryRepository repo = FakeProfileSummaryRepository(
        random: Random(1),
      );

      final Result<ProfileSummary> result = await repo.getProfileSummary();

      expect(result, isA<Ok<ProfileSummary>>());
      final ProfileSummary s = (result as Ok<ProfileSummary>).value;
      // Reconciles with FakeProfileRepository and the Stats demo.
      expect(s.displayName, 'Doniyor');
      expect(s.countryCode, 'GB');
      expect(s.elo, 1284);
      expect(s.bestSingleMs, 8420);
      expect(s.bestSingleEvent, '3x3');
      expect(s.rank?.position, 47);
      expect(s.winRate, closeTo(0.68, 0.001));
    });

    test('readFailureRate: 1 returns Err', () async {
      final FakeProfileSummaryRepository repo = FakeProfileSummaryRepository(
        random: Random(1),
        readFailureRate: 1,
      );

      final Result<ProfileSummary> result = await repo.getProfileSummary();
      expect(result, isA<Err<ProfileSummary>>());
    });

    test('honors event/rank_scope overrides without throwing', () async {
      final FakeProfileSummaryRepository repo = FakeProfileSummaryRepository(
        random: Random(1),
      );
      final Result<ProfileSummary> result = await repo.getProfileSummary(
        event: '4x4',
        rankScope: 'country',
      );
      expect(result, isA<Ok<ProfileSummary>>());
    });
  });
}
