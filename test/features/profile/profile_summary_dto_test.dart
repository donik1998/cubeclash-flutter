import 'package:cubeclash/features/profile/data/models/profile_summary_dto.dart';
import 'package:cubeclash/features/profile/domain/entities/profile_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// One well-formed wire response.
Map<String, dynamic> body({
  Map<String, dynamic>? user,
  Object? rank = _absent,
  Map<String, dynamic>? stats,
  Object? friendCount = 48,
}) =>
    <String, dynamic>{
      'user': user ??
          <String, dynamic>{
            'id': '0e5b-uuid',
            'display_name': 'cuber_98',
            'country': 'UZ',
            'elo': 1180,
          },
      if (rank != _absent)
        'rank': rank ??
            <String, dynamic>{
              'event': '3x3',
              'metric': 'single',
              'scope': 'global',
              'position': 1204,
            },
      'stats': stats ??
          <String, dynamic>{
            'best_single_ms': 8420,
            'best_single_event': '3x3',
            'total_solves': 3204,
            'win_rate': 0.68,
            'wins': 217,
            'losses': 102,
          },
      'friend_count': friendCount,
    };

const Object _absent = Object();

void main() {
  group('real captured bytes — me_profile.json', () {
    test('the live server response maps to a domain summary', () {
      final ProfileSummary? summary = ProfileSummaryMapper.toDomain(
        ProfileSummaryDto.fromJson(loadApiFixture('me_profile')),
      );

      expect(summary, isNotNull);
      expect(summary!.displayName, 'kian_r');
      expect(summary.countryCode, 'IR');
      expect(summary.elo, 1000);
      expect(summary.rank?.position, 1);
      expect(summary.totalSolves, 12);
      expect(summary.winRate, isNull,
          reason: 'win_rate is null until races exist');
      expect(summary.friendCount, 0);
    });
  });

  group('ProfileSummaryDto', () {
    test('decoding {} throws nothing and leaves every field null', () {
      final ProfileSummaryDto dto =
          ProfileSummaryDto.fromJson(<String, dynamic>{});

      expect(dto.user, isNull);
      expect(dto.rank, isNull);
      expect(dto.stats, isNull);
      expect(dto.friendCount, isNull);
    });

    test('decoding {} for every nested object throws nothing, all fields null',
        () {
      final ProfileUserDto user = ProfileUserDto.fromJson(<String, dynamic>{});
      final ProfileRankDto r = ProfileRankDto.fromJson(<String, dynamic>{});
      final ProfileStatsDto s = ProfileStatsDto.fromJson(<String, dynamic>{});

      expect(<Object?>[user.id, user.displayName, user.country, user.elo],
          everyElement(isNull));
      expect(<Object?>[r.event, r.metric, r.scope, r.position],
          everyElement(isNull));
      expect(
        <Object?>[
          s.bestSingleMs,
          s.bestSingleEvent,
          s.totalSolves,
          s.winRate,
          s.wins,
          s.losses,
        ],
        everyElement(isNull),
      );
    });

    test('round-trips toJson -> fromJson unchanged', () {
      final ProfileSummaryDto a = ProfileSummaryDto.fromJson(body());
      final ProfileSummaryDto b = ProfileSummaryDto.fromJson(a.toJson());

      expect(b.user?.id, a.user?.id);
      expect(b.user?.displayName, a.user?.displayName);
      expect(b.user?.country, a.user?.country);
      expect(b.user?.elo, a.user?.elo);
      expect(b.rank?.position, a.rank?.position);
      expect(b.rank?.event, a.rank?.event);
      expect(b.stats?.bestSingleMs, a.stats?.bestSingleMs);
      expect(b.stats?.winRate, a.stats?.winRate);
      expect(b.friendCount, a.friendCount);
    });

    test('coerces numeric fields that arrive as doubles', () {
      final ProfileSummaryDto dto = ProfileSummaryDto.fromJson(
        body(
          user: <String, dynamic>{
            'id': 'x',
            'display_name': 'n',
            'elo': 1180.0,
          },
          stats: <String, dynamic>{'total_solves': 3204.0, 'win_rate': 1},
        ),
      );
      expect(dto.user?.elo, 1180);
      expect(dto.stats?.totalSolves, 3204);
      // win_rate arriving as an int coerces to double.
      expect(dto.stats?.winRate, 1.0);
    });
  });

  group('ProfileSummaryMapper — drop vs default', () {
    ProfileSummary? map(Map<String, dynamic> json) =>
        ProfileSummaryMapper.toDomain(ProfileSummaryDto.fromJson(json));

    test('nominal maps every field through', () {
      // Pass rank: null so body() emits its default rank object (see the
      // helper) rather than omitting it — this case exercises a present rank.
      final ProfileSummary s = map(body(rank: null))!;

      expect(s.id, '0e5b-uuid');
      expect(s.displayName, 'cuber_98');
      expect(s.countryCode, 'UZ');
      expect(s.elo, 1180);
      expect(s.rank?.position, 1204);
      expect(s.rank?.metric, 'single');
      expect(s.rank?.scope, 'global');
      expect(s.bestSingleMs, 8420);
      expect(s.bestSingleEvent, '3x3');
      expect(s.totalSolves, 3204);
      expect(s.winRate, 0.68);
      expect(s.wins, 217);
      expect(s.losses, 102);
      expect(s.friendCount, 48);
    });

    test('missing id → mapper returns null (never fabricate identity)', () {
      expect(
        map(body(user: <String, dynamic>{'display_name': 'x'})),
        isNull,
      );
    });

    test('empty id → mapper returns null', () {
      expect(
        map(body(user: <String, dynamic>{'id': '', 'display_name': 'x'})),
        isNull,
      );
    });

    test('missing display_name → mapper returns null', () {
      expect(map(body(user: <String, dynamic>{'id': 'x'})), isNull);
    });

    test('empty display_name → mapper returns null', () {
      expect(
        map(body(user: <String, dynamic>{'id': 'x', 'display_name': ''})),
        isNull,
      );
    });

    test('null country is preserved (UI drops the segment)', () {
      final ProfileSummary s = map(body(
        user: <String, dynamic>{
          'id': 'x',
          'display_name': 'n',
          'country': null,
          'elo': 1180,
        },
      ))!;
      expect(s.countryCode, isNull);
    });

    test('rank object absent → null rank', () {
      // body() omits `rank` entirely by default.
      final ProfileSummary s = map(body())!;
      expect(s.rank, isNull);
    });

    test('rank present but position missing → null rank', () {
      final ProfileSummary s = map(body(
        rank: <String, dynamic>{
          'event': '3x3',
          'metric': 'single',
          'scope': 'global',
        },
      ))!;
      expect(s.rank, isNull);
    });

    test('elo defaults to 1000 when missing', () {
      final ProfileSummary s = map(body(
        user: <String, dynamic>{'id': 'x', 'display_name': 'n'},
      ))!;
      expect(s.elo, 1000);
    });

    test('best_single_ms and win_rate null are preserved', () {
      final ProfileSummary s = map(body(
        stats: <String, dynamic>{
          'best_single_ms': null,
          'win_rate': null,
        },
      ))!;
      expect(s.bestSingleMs, isNull);
      expect(s.winRate, isNull);
    });

    test('best_single_event defaults to 3x3 when missing', () {
      final ProfileSummary s = map(body(stats: <String, dynamic>{}))!;
      expect(s.bestSingleEvent, '3x3');
    });

    test('total_solves, wins, losses, friend_count default to 0', () {
      final ProfileSummary s = map(body(
        stats: <String, dynamic>{},
        friendCount: null,
      ))!;
      expect(s.totalSolves, 0);
      expect(s.wins, 0);
      expect(s.losses, 0);
      expect(s.friendCount, 0);
    });

    test('missing stats object entirely → neutral defaults, still maps', () {
      final ProfileSummary s = ProfileSummaryMapper.toDomain(
        const ProfileSummaryDto(
          user: ProfileUserDto(id: 'x', displayName: 'n'),
        ),
      )!;
      expect(s.totalSolves, 0);
      expect(s.bestSingleMs, isNull);
      expect(s.bestSingleEvent, '3x3');
    });
  });
}
