import 'package:flutter/foundation.dart';

import '../../domain/entities/leaderboard_entry.dart';

/// Wire ↔ domain mapping for `GET /leaderboard`.
///
/// Field names mirror the documented response (leaderboard spec § "API
/// contract"): `snake_case` throughout, and this is the *only* layer that knows
/// the wire names.
///
/// **Every field is nullable — no exceptions**, including `rank`, `user_id`,
/// `display_name` and `value_ms`. "Required" is the server's intent, not a
/// guarantee about the bytes that arrived: a version skew, a nullable column, or
/// a bug can drop any of them. `fromJson({})` must therefore produce an
/// all-null DTO and **throw nothing** — no `as String`, no `!`. The decision
/// about what a missing field *means* lives one layer down, in the mapper.
///
/// The row's ranking value travels as `value_ms` — the metric's *ranking key*,
/// not raw `time_ms` (a `+2` is folded in, a DNF is excluded upstream). It maps
/// to [LeaderboardEntry.timeMs] because the UI formats it as a time.
@immutable
class LeaderboardEntryDto {
  const LeaderboardEntryDto({
    this.rank,
    this.userId,
    this.displayName,
    this.country,
    this.valueMs,
    this.event,
    this.solvedAt,
  });

  factory LeaderboardEntryDto.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntryDto(
        rank: _int(json['rank']),
        userId: json['user_id'] as String?,
        displayName: json['display_name'] as String?,
        // ISO 3166-1 alpha-2 code, or null. Never a display name — the code →
        // name mapping is a client display concern.
        country: json['country'] as String?,
        valueMs: _int(json['value_ms']),
        event: json['event'] as String?,
        solvedAt: json['solved_at'] as String?,
      );

  final int? rank;
  final String? userId;
  final String? displayName;
  final String? country;
  final int? valueMs;
  final String? event;

  /// ISO 8601 with a UTC offset, as a raw string. Parsed in the mapper.
  final String? solvedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rank': rank,
        'user_id': userId,
        'display_name': displayName,
        'country': country,
        'value_ms': valueMs,
        'event': event,
        'solved_at': solvedAt,
      };
}

/// The full `GET /leaderboard` response envelope. Also a total mirror of the
/// wire: `items` absent → empty list, `viewer` absent → null, and decoding `{}`
/// throws nothing.
@immutable
class LeaderboardResponseDto {
  const LeaderboardResponseDto({
    this.items,
    this.nextCursor,
    this.viewer,
  });

  factory LeaderboardResponseDto.fromJson(Map<String, dynamic> json) {
    final dynamic rawItems = json['items'];
    final dynamic rawViewer = json['viewer'];

    return LeaderboardResponseDto(
      items: rawItems is List
          ? <LeaderboardEntryDto>[
              for (final dynamic e in rawItems)
                LeaderboardEntryDto.fromJson(_asMap(e)),
            ]
          : null,
      nextCursor: json['next_cursor'] as String?,
      viewer: rawViewer is Map
          ? LeaderboardEntryDto.fromJson(_asMap(rawViewer))
          : null,
    );
  }

  final List<LeaderboardEntryDto>? items;
  final String? nextCursor;
  final LeaderboardEntryDto? viewer;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'items': items?.map((LeaderboardEntryDto e) => e.toJson()).toList(),
        'next_cursor': nextCursor,
        'viewer': viewer?.toJson(),
      };
}

/// DTO → domain for the leaderboard. The single place that decides what
/// "missing" means for each field.
class LeaderboardMapper {
  const LeaderboardMapper._();

  /// Maps one row, or returns null when the row is unusable and must be dropped.
  ///
  /// Drop rules (leaderboard spec § "Client notes"):
  ///   * missing `user_id`, `rank`, `value_ms`, **or** `display_name` → the row
  ///     is load-bearing for identity or meaning; return null. A row without an
  ///     id can't be tapped through to a profile; a nameless or rank-less or
  ///     valueless row is meaningless on a ranking. Never fabricate any of them.
  ///   * missing `country` → a genuinely optional field; stays nullable.
  static LeaderboardEntry? entryToDomain(
    LeaderboardEntryDto dto, {
    bool isCurrentUser = false,
  }) {
    final int? rank = dto.rank;
    final String? userId = dto.userId;
    final String? displayName = dto.displayName;
    final int? valueMs = dto.valueMs;

    if (rank == null ||
        userId == null ||
        userId.isEmpty ||
        displayName == null ||
        displayName.isEmpty ||
        valueMs == null) {
      _logDrop(dto);
      return null;
    }

    return LeaderboardEntry(
      userId: userId,
      rank: rank,
      displayName: displayName,
      timeMs: valueMs,
      countryCode: dto.country, // stays nullable, deliberately
      isCurrentUser: isCurrentUser,
    );
  }

  /// Maps the whole response. **One bad element never blanks the list** — each
  /// row is mapped, nulls are dropped, the rest are kept. The `viewer` is mapped
  /// separately with `isCurrentUser: true`; a malformed viewer object simply
  /// yields a null viewer (the pin is hidden) rather than taking down the page.
  static Leaderboard responseToDomain(LeaderboardResponseDto dto) {
    final List<LeaderboardEntryDto> rawRows =
        dto.items ?? const <LeaderboardEntryDto>[];

    final List<LeaderboardEntry> entries = <LeaderboardEntry>[];
    for (final LeaderboardEntryDto row in rawRows) {
      final LeaderboardEntry? mapped = entryToDomain(row);
      if (mapped != null) entries.add(mapped);
    }

    final int dropped = rawRows.length - entries.length;
    if (dropped > 0) {
      debugPrint(
        'LeaderboardMapper: dropped $dropped of ${rawRows.length} rows '
        '(missing user_id / rank / value_ms / display_name).',
      );
    }

    final LeaderboardEntry? viewer = dto.viewer == null
        ? null
        : entryToDomain(dto.viewer!, isCurrentUser: true);

    return Leaderboard(
      entries: entries,
      viewer: viewer,
      nextCursor: dto.nextCursor,
    );
  }

  static void _logDrop(LeaderboardEntryDto dto) {
    // A drop is a real signal that client and server disagree — log the id when
    // we have one so a vanished row is traceable. debugPrint is tree-shaken out
    // of release builds; swap in the analytics seam when one exists here.
    debugPrint(
      'LeaderboardMapper: dropped row (user_id=${dto.userId}, '
      'rank=${dto.rank}, value_ms=${dto.valueMs}, '
      'display_name=${dto.displayName}).',
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int? _int(dynamic value) => value is num ? value.toInt() : null;
