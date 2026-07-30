import 'package:flutter/foundation.dart';

import '../../domain/entities/profile_summary.dart';

/// Wire ↔ domain mapping for `GET /me/profile` (spec §6).
///
/// This is the *only* layer that knows the wire's `snake_case` names and its
/// nesting (`user` / `rank` / `stats` / `friend_count`).
///
/// **Every field is nullable — no exceptions**, including `user.id` and
/// `user.display_name` that the contract marks NOT NULL. "Required" is the
/// server's intent, not a guarantee about the bytes that arrived: a version
/// skew, a nullable column, or a bug can drop any of them. `fromJson({})` must
/// therefore produce an all-null DTO and **throw nothing** — no `as String`,
/// no `!`. The decision about what a missing field *means* lives one layer
/// down, in [ProfileSummaryMapper].
@immutable
class ProfileSummaryDto {
  const ProfileSummaryDto({
    this.user,
    this.rank,
    this.stats,
    this.friendCount,
  });

  factory ProfileSummaryDto.fromJson(Map<String, dynamic> json) {
    final dynamic rawUser = json['user'];
    final dynamic rawRank = json['rank'];
    final dynamic rawStats = json['stats'];
    return ProfileSummaryDto(
      user: rawUser is Map ? ProfileUserDto.fromJson(_asMap(rawUser)) : null,
      // `rank` is a nullable object on the wire (null when unranked). Only
      // build a DTO when an object actually arrived.
      rank: rawRank is Map ? ProfileRankDto.fromJson(_asMap(rawRank)) : null,
      stats:
          rawStats is Map ? ProfileStatsDto.fromJson(_asMap(rawStats)) : null,
      friendCount: _int(json['friend_count']),
    );
  }

  final ProfileUserDto? user;
  final ProfileRankDto? rank;
  final ProfileStatsDto? stats;
  final int? friendCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user': user?.toJson(),
        'rank': rank?.toJson(),
        'stats': stats?.toJson(),
        'friend_count': friendCount,
      };
}

/// The `user` sub-object. `avatar_url` is deliberately absent — spec §11.1
/// removed it from the contract; the avatar is always an initials placeholder.
@immutable
class ProfileUserDto {
  const ProfileUserDto({
    this.id,
    this.displayName,
    this.country,
    this.elo,
  });

  factory ProfileUserDto.fromJson(Map<String, dynamic> json) => ProfileUserDto(
        id: json['id'] as String?,
        displayName: json['display_name'] as String?,
        // ISO 3166-1 alpha-2 code, or null. Never a display name.
        country: json['country'] as String?,
        elo: _int(json['elo']),
      );

  final String? id;
  final String? displayName;
  final String? country;
  final int? elo;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'display_name': displayName,
        'country': country,
        'elo': elo,
      };
}

/// The `rank` sub-object. Absent entirely when the viewer is unranked; even
/// when present, `position` can be missing (which the mapper treats as no rank).
@immutable
class ProfileRankDto {
  const ProfileRankDto({
    this.event,
    this.metric,
    this.scope,
    this.position,
  });

  factory ProfileRankDto.fromJson(Map<String, dynamic> json) => ProfileRankDto(
        event: json['event'] as String?,
        metric: json['metric'] as String?,
        scope: json['scope'] as String?,
        position: _int(json['position']),
      );

  final String? event;
  final String? metric;
  final String? scope;
  final int? position;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'event': event,
        'metric': metric,
        'scope': scope,
        'position': position,
      };
}

/// The `stats` sub-object.
@immutable
class ProfileStatsDto {
  const ProfileStatsDto({
    this.bestSingleMs,
    this.bestSingleEvent,
    this.totalSolves,
    this.winRate,
    this.wins,
    this.losses,
  });

  factory ProfileStatsDto.fromJson(Map<String, dynamic> json) =>
      ProfileStatsDto(
        bestSingleMs: _int(json['best_single_ms']),
        bestSingleEvent: json['best_single_event'] as String?,
        totalSolves: _int(json['total_solves']),
        winRate: _double(json['win_rate']),
        wins: _int(json['wins']),
        losses: _int(json['losses']),
      );

  final int? bestSingleMs;
  final String? bestSingleEvent;
  final int? totalSolves;

  /// A 0..1 ratio on the wire, not a percent.
  final double? winRate;
  final int? wins;
  final int? losses;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'best_single_ms': bestSingleMs,
        'best_single_event': bestSingleEvent,
        'total_solves': totalSolves,
        'win_rate': winRate,
        'wins': wins,
        'losses': losses,
      };
}

/// DTO → domain for the profile summary. The single place that decides what
/// "missing" means for each field.
class ProfileSummaryMapper {
  const ProfileSummaryMapper._();

  /// Maps the response, or returns null when the record is unusable and the
  /// repository should surface a parse failure.
  ///
  /// Drop-vs-default rules (spec §6 / §11):
  ///   * `user.id`, `user.display_name` → **load-bearing for identity**. If
  ///     either is missing or empty, return null — never fabricate identity.
  ///   * `user.country` → genuinely optional; stays nullable (null → the UI
  ///     drops the country segment).
  ///   * `user.elo` → non-null, default **1000** (schema default) if missing.
  ///   * `rank` (whole object) → nullable. Absent object *or* a missing
  ///     `position` yields a null rank — never fabricate a rank.
  ///   * `stats.best_single_ms` → stays nullable (null → "—").
  ///   * `stats.best_single_event` → non-null, default `'3x3'`.
  ///   * `stats.total_solves` → non-null, default 0.
  ///   * `stats.win_rate` → stays nullable (null → "—").
  ///   * `stats.wins` / `stats.losses` → non-null, default 0.
  ///   * `friend_count` → non-null, default 0.
  static ProfileSummary? toDomain(ProfileSummaryDto dto) {
    final ProfileUserDto? user = dto.user;
    final String? id = user?.id;
    final String? displayName = user?.displayName;

    if (id == null ||
        id.isEmpty ||
        displayName == null ||
        displayName.isEmpty) {
      _logDrop(dto);
      return null;
    }

    final ProfileStatsDto stats =
        dto.stats ?? const ProfileStatsDto(); // all-null neutral fallback

    return ProfileSummary(
      id: id,
      displayName: displayName,
      countryCode: user?.country, // stays nullable, deliberately
      elo: user?.elo ?? 1000,
      rank: _rankToDomain(dto.rank),
      bestSingleMs: stats.bestSingleMs, // stays nullable, deliberately
      bestSingleEvent: stats.bestSingleEvent ?? '3x3',
      totalSolves: stats.totalSolves ?? 0,
      winRate: stats.winRate, // stays nullable, deliberately
      wins: stats.wins ?? 0,
      losses: stats.losses ?? 0,
      friendCount: dto.friendCount ?? 0,
    );
  }

  /// A rank is meaningful only with a position. Absent object or absent
  /// position → null (the UI drops the "#…" segment). `event`/`metric`/`scope`
  /// echo back the request, so they default rather than drop the rank.
  static ProfileRank? _rankToDomain(ProfileRankDto? dto) {
    if (dto == null) return null;
    final int? position = dto.position;
    if (position == null) return null;
    return ProfileRank(
      event: dto.event ?? '3x3',
      metric: dto.metric ?? 'single',
      scope: dto.scope ?? 'global',
      position: position,
    );
  }

  static void _logDrop(ProfileSummaryDto dto) {
    // A drop is a real signal that client and server disagree. debugPrint is
    // tree-shaken out of release builds; swap in the analytics seam when one
    // exists here.
    debugPrint(
      'ProfileSummaryMapper: dropped profile (id=${dto.user?.id}, '
      'display_name=${dto.user?.displayName}) — missing identity.',
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int? _int(dynamic value) => value is num ? value.toInt() : null;

double? _double(dynamic value) => value is num ? value.toDouble() : null;
