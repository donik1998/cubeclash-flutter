import 'dart:convert';
import 'dart:io';

/// Loads a real server response captured under `test/fixtures/api/`.
///
/// These are **actual bytes** from a running `cubeclash-backend` (localhost:3100,
/// July 2026), not hand-invented JSON. DTO tests decode them so a drift between
/// the client's parsing and the server's real shape fails here — the whole point
/// of the live-wiring pass.
///
/// `flutter test` runs with the package root as its working directory, so the
/// relative path resolves without any asset bundling.
Map<String, dynamic> loadApiFixture(String name) {
  final File file = File('test/fixtures/api/$name.json');
  final Object? decoded = jsonDecode(file.readAsStringSync());
  return Map<String, dynamic>.from(decoded! as Map);
}

/// The raw decoded value (for fixtures whose top level is not an object).
Object? loadApiFixtureRaw(String name) =>
    jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync());
