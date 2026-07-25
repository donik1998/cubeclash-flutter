import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/solve.dart';
import '../../domain/repositories/last_event_store.dart';
import '../models/solve_dto.dart';

/// The timer's local persistence, on `shared_preferences` — **no network and
/// no local database**.
///
/// The no-backend build has nowhere else to keep a user's solves, so without
/// this a relaunch loses the session. It persists two things:
///   * the current session's solves (`timer.session.v1`), whole-list
///     write-through — sessions are tens to low-hundreds of solves, so there is
///     nothing to gain from incremental writes;
///   * the last-selected event id (`timer.last_event.v1`), so the timer reopens
///     where the user left off.
///
/// Reads are **defensive**, matching `SettingsRepositoryImpl`: any parse or
/// format error decodes to an empty session rather than throwing, because a
/// corrupt preference must never stop the app from launching.
///
/// When the backend lands this becomes the offline cache/outbox in front of
/// `SolveRepositoryImpl` — which is why it depends on nothing from `dio`.
class LocalSolveStore implements LastEventStore {
  const LocalSolveStore();

  /// Versioned so a future schema change can be migrated rather than
  /// misread — a `v2` reader ignores a `v1` value it can't understand.
  static const String _sessionKey = 'timer.session.v1';
  static const String _lastEventKey = 'timer.last_event.v1';

  /// The persisted session, oldest first. Returns `[]` on absence or any
  /// decode failure — never throws.
  Future<List<Solve>> loadSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return <Solve>[];

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return <Solve>[];
      return decoded
          .map((dynamic e) =>
              SolveDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // A corrupt value is discarded, not surfaced — the alternative is an app
      // that won't launch because one preference went bad.
      return <Solve>[];
    }
  }

  /// Overwrites the persisted session with [solves].
  Future<void> saveSession(List<Solve> solves) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      solves.map(SolveDto.toJson).toList(),
    );
    await prefs.setString(_sessionKey, encoded);
  }

  @override
  Future<String?> loadLastEvent() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? value = prefs.getString(_lastEventKey);
    return (value == null || value.isEmpty) ? null : value;
  }

  @override
  Future<void> saveLastEvent(String eventId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastEventKey, eventId);
  }
}
