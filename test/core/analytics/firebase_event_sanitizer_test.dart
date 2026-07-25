import 'package:cubeclash/core/analytics/firebase_event_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// These encode Firebase's documented limits so a violation fails here rather
/// than being discovered as a silently-missing column in a dashboard weeks
/// later. Pure Dart — no Firebase, no network.
void main() {
  group('event names', () {
    test('passes the app\'s real event names through untouched', () {
      // The full taxonomy the app actually emits — all already legal.
      const List<String> taxonomy = <String>[
        'inspection_started',
        'inspection_cue',
        'solve_started',
        'solve_completed',
        'scramble_generated',
        'penalty_applied',
        'race_search_started',
        'race_matched',
        'race_solve_started',
        'race_solve_submitted',
        'stats_viewed',
        'leaderboard_viewed',
        'theme_changed',
        'timer_style_changed',
      ];

      for (final String name in taxonomy) {
        expect(FirebaseEventSanitizer.eventName(name), name);
      }
    });

    test('replaces illegal characters', () {
      expect(FirebaseEventSanitizer.eventName('solve completed!'),
          'solve_completed_');
      expect(FirebaseEventSanitizer.eventName('race-matched'), 'race_matched');
    });

    test('forces a leading letter', () {
      expect(FirebaseEventSanitizer.eventName('2x2_solved'), 'e_2x2_solved');
      expect(FirebaseEventSanitizer.eventName('_private'), 'e__private');
    });

    test('escapes Firebase\'s reserved prefixes rather than dropping', () {
      expect(FirebaseEventSanitizer.eventName('firebase_boot'),
          'app_firebase_boot');
      expect(
          FirebaseEventSanitizer.eventName('google_thing'), 'app_google_thing');
      expect(FirebaseEventSanitizer.eventName('ga_thing'), 'app_ga_thing');
    });

    test('truncates to 40 characters', () {
      final String long = 'a' * 60;
      expect(FirebaseEventSanitizer.eventName(long)!.length,
          FirebaseEventSanitizer.maxNameLength);
    });

    test('returns null for an empty name — nothing to send', () {
      expect(FirebaseEventSanitizer.eventName(''), isNull);
    });
  });

  group('parameters', () {
    test('keeps strings and numbers as-is', () {
      final Map<String, Object>? out = FirebaseEventSanitizer.parameters(
        <String, Object?>{'event': '3x3', 'time_ms': 12340, 'ratio': 1.5},
      );
      expect(out, <String, Object>{
        'event': '3x3',
        'time_ms': 12340,
        'ratio': 1.5,
      });
    });

    test('converts bool to 1/0 so it stays queryable as a number', () {
      // `scramble_generated` really does send a bool.
      final Map<String, Object>? out = FirebaseEventSanitizer.parameters(
        <String, Object?>{'available': true, 'missing': false},
      );
      expect(out, <String, Object>{'available': 1, 'missing': 0});
    });

    test('drops nulls rather than sending them', () {
      // `race_matched.opponent_id` and `race_solve_started.race_id` are both
      // nullable at the call site.
      final Map<String, Object>? out = FirebaseEventSanitizer.parameters(
        <String, Object?>{'opponent_id': null, 'wait_ms': 900},
      );
      expect(out, <String, Object>{'wait_ms': 900});
      expect(out!.containsKey('opponent_id'), isFalse);
    });

    test('returns null when nothing survives', () {
      expect(
        FirebaseEventSanitizer.parameters(<String, Object?>{'a': null}),
        isNull,
      );
      expect(FirebaseEventSanitizer.parameters(<String, Object?>{}), isNull);
    });

    test('truncates long string values to 100 characters', () {
      final Map<String, Object>? out = FirebaseEventSanitizer.parameters(
        <String, Object?>{'scramble': 'R' * 250},
      );
      expect((out!['scramble']! as String).length,
          FirebaseEventSanitizer.maxValueLength);
    });

    test('stringifies anything that is neither num nor bool', () {
      final Map<String, Object>? out = FirebaseEventSanitizer.parameters(
        <String, Object?>{'when': DateTime.utc(2026, 7, 24)},
      );
      expect(out!['when'], isA<String>());
    });

    test('sanitizes parameter names too', () {
      final Map<String, Object>? out = FirebaseEventSanitizer.parameters(
        <String, Object?>{'at s': 4, '2nd': 'x'},
      );
      expect(out!.keys, containsAll(<String>['at_s', 'e_2nd']));
    });

    test('caps at 25 parameters', () {
      final Map<String, Object?> raw = <String, Object?>{
        for (int i = 0; i < 40; i++) 'p$i': i,
      };
      expect(FirebaseEventSanitizer.parameters(raw),
          hasLength(FirebaseEventSanitizer.maxParameters));
    });
  });
}
