import 'package:cubeclash/features/stats/data/models/leaderboard_dto.dart';
import 'package:cubeclash/features/stats/domain/entities/leaderboard_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// One well-formed wire row.
Map<String, dynamic> row({
  Object? rank = 1,
  Object? userId = 'u1',
  Object? displayName = 'kian_r',
  Object? country = 'IR',
  Object? valueMs = 6310,
  Object? event = '3x3',
  Object? solvedAt = '2026-07-20T09:12:03.000Z',
}) =>
    <String, dynamic>{
      'rank': rank,
      'user_id': userId,
      'display_name': displayName,
      'country': country,
      'value_ms': valueMs,
      'event': event,
      'solved_at': solvedAt,
    };

void main() {
  group('LeaderboardEntryDto', () {
    test('decoding {} throws nothing and leaves every field null', () {
      final LeaderboardEntryDto dto =
          LeaderboardEntryDto.fromJson(<String, dynamic>{});

      expect(dto.rank, isNull);
      expect(dto.userId, isNull);
      expect(dto.displayName, isNull);
      expect(dto.country, isNull);
      expect(dto.valueMs, isNull);
      expect(dto.event, isNull);
      expect(dto.solvedAt, isNull);
    });

    test('round-trips toJson -> fromJson unchanged', () {
      final LeaderboardEntryDto a = LeaderboardEntryDto.fromJson(row());
      final LeaderboardEntryDto b = LeaderboardEntryDto.fromJson(a.toJson());

      expect(b.rank, a.rank);
      expect(b.userId, a.userId);
      expect(b.displayName, a.displayName);
      expect(b.country, a.country);
      expect(b.valueMs, a.valueMs);
      expect(b.event, a.event);
      expect(b.solvedAt, a.solvedAt);
    });

    test('coerces a numeric value_ms/rank that arrives as a double', () {
      final LeaderboardEntryDto dto = LeaderboardEntryDto.fromJson(
        row(rank: 3.0, valueMs: 6310.0),
      );
      expect(dto.rank, 3);
      expect(dto.valueMs, 6310);
    });
  });

  group('LeaderboardResponseDto', () {
    test('decoding {} throws nothing (items null, viewer null)', () {
      final LeaderboardResponseDto dto =
          LeaderboardResponseDto.fromJson(<String, dynamic>{});

      expect(dto.items, isNull);
      expect(dto.nextCursor, isNull);
      expect(dto.viewer, isNull);
    });

    test('parses items, next_cursor and viewer', () {
      final LeaderboardResponseDto dto = LeaderboardResponseDto.fromJson(
        <String, dynamic>{
          'items': <dynamic>[row(rank: 1, userId: 'u1')],
          'next_cursor': 'abc',
          'viewer': row(rank: 1204, userId: 'me', displayName: 'You'),
        },
      );

      expect(dto.items, hasLength(1));
      expect(dto.nextCursor, 'abc');
      expect(dto.viewer?.userId, 'me');
    });

    test('round-trips toJson -> fromJson', () {
      final LeaderboardResponseDto a = LeaderboardResponseDto.fromJson(
        <String, dynamic>{
          'items': <dynamic>[row()],
          'next_cursor': 'abc',
          'viewer': row(userId: 'me'),
        },
      );
      final LeaderboardResponseDto b =
          LeaderboardResponseDto.fromJson(a.toJson());

      expect(b.items, hasLength(1));
      expect(b.nextCursor, 'abc');
      expect(b.viewer?.userId, 'me');
    });
  });

  group('LeaderboardMapper drop rules', () {
    LeaderboardEntry? mapOne(Map<String, dynamic> json) =>
        LeaderboardMapper.entryToDomain(LeaderboardEntryDto.fromJson(json));

    test('a complete row maps to a domain entry', () {
      final LeaderboardEntry? e = mapOne(row());
      expect(e, isNotNull);
      expect(e!.userId, 'u1');
      expect(e.rank, 1);
      expect(e.displayName, 'kian_r');
      expect(e.timeMs, 6310, reason: 'value_ms maps to timeMs');
      expect(e.countryCode, 'IR');
      expect(e.isCurrentUser, isFalse);
    });

    test('missing user_id -> dropped', () {
      expect(mapOne(row(userId: null)), isNull);
    });

    test('empty user_id -> dropped', () {
      expect(mapOne(row(userId: '')), isNull);
    });

    test('missing rank -> dropped', () {
      expect(mapOne(row(rank: null)), isNull);
    });

    test('missing value_ms -> dropped', () {
      expect(mapOne(row(valueMs: null)), isNull);
    });

    test('missing display_name -> dropped', () {
      expect(mapOne(row(displayName: null)), isNull);
    });

    test('missing country -> kept, countryCode stays null', () {
      final LeaderboardEntry? e = mapOne(row(country: null));
      expect(e, isNotNull);
      expect(e!.countryCode, isNull);
    });

    test('an unknown/raw country code passes through untouched (UI maps it)',
        () {
      final LeaderboardEntry? e = mapOne(row(country: 'ZZ'));
      expect(e?.countryCode, 'ZZ');
    });
  });

  group('LeaderboardMapper list behaviour', () {
    test('one bad element is dropped, the good ones survive', () {
      final LeaderboardResponseDto dto = LeaderboardResponseDto.fromJson(
        <String, dynamic>{
          'items': <dynamic>[
            row(rank: 1, userId: 'u1'),
            <String, dynamic>{'rank': 2}, // missing user_id/name/value_ms
            row(rank: 3, userId: 'u3'),
          ],
          'next_cursor': 'next',
        },
      );

      final Leaderboard board = LeaderboardMapper.responseToDomain(dto);

      expect(board.entries, hasLength(2));
      expect(
        board.entries.map((LeaderboardEntry e) => e.userId),
        <String>['u1', 'u3'],
      );
      expect(board.nextCursor, 'next');
    });

    test('empty response -> empty entries, null viewer, null cursor', () {
      final Leaderboard board = LeaderboardMapper.responseToDomain(
        LeaderboardResponseDto.fromJson(<String, dynamic>{}),
      );
      expect(board.entries, isEmpty);
      expect(board.viewer, isNull);
      expect(board.nextCursor, isNull);
    });

    test('viewer maps with isCurrentUser = true', () {
      final Leaderboard board = LeaderboardMapper.responseToDomain(
        LeaderboardResponseDto.fromJson(<String, dynamic>{
          'items': <dynamic>[row()],
          'viewer': row(rank: 1204, userId: 'me', displayName: 'You'),
        }),
      );
      expect(board.viewer, isNotNull);
      expect(board.viewer!.isCurrentUser, isTrue);
      expect(board.viewer!.rank, 1204);
    });

    test('a malformed viewer object yields a null viewer, not a crash', () {
      final Leaderboard board = LeaderboardMapper.responseToDomain(
        LeaderboardResponseDto.fromJson(<String, dynamic>{
          'items': <dynamic>[row()],
          'viewer': <String, dynamic>{'rank': 5}, // no id/name/value_ms
        }),
      );
      expect(board.entries, hasLength(1));
      expect(board.viewer, isNull);
    });

    test('viewerVisible flips when the viewer is on the page', () {
      final Leaderboard offPage = LeaderboardMapper.responseToDomain(
        LeaderboardResponseDto.fromJson(<String, dynamic>{
          'items': <dynamic>[row(userId: 'u1')],
          'viewer': row(userId: 'me'),
        }),
      );
      expect(offPage.viewerVisible, isFalse);

      final Leaderboard onPage = LeaderboardMapper.responseToDomain(
        LeaderboardResponseDto.fromJson(<String, dynamic>{
          'items': <dynamic>[row(userId: 'me')],
          'viewer': row(userId: 'me'),
        }),
      );
      expect(onPage.viewerVisible, isTrue);
    });
  });
}
