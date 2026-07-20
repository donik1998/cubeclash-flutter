import 'package:cubeclash/core/widgets/time_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeText.format', () {
    test('formats sub-minute times as s.cc', () {
      expect(TimeText.format(12340), '12.34');
      expect(TimeText.format(8000), '8.00');
      expect(TimeText.format(999), '0.99');
      expect(TimeText.format(0), '0.00');
    });

    test('formats a minute or more as m:ss.cc with a padded seconds field', () {
      expect(TimeText.format(60000), '1:00.00');
      expect(TimeText.format(83450), '1:23.45');
      expect(TimeText.format(69990), '1:09.99');
    });

    test('drops the hundredths from ten minutes up (WCA 9f2)', () {
      // Regulation 9f2: results of ten minutes or more are truncated to
      // seconds, not hundredths. The boundary is exact.
      expect(TimeText.format(599990), '9:59.99');
      expect(TimeText.format(600000), '10:00');
      expect(TimeText.format(754000), '12:34');
    });

    test('formats an hour or more with three fields', () {
      // A Multi-Blind attempt runs to sixty minutes (Regulation H1b), so the
      // readout has to survive an hours field.
      expect(TimeText.format(3600000), '1:00:00');
      expect(TimeText.format(3862000), '1:04:22');
    });

    test('truncates hundredths rather than rounding up', () {
      // A timer must never round a solve up into a time not achieved.
      expect(TimeText.format(12349), '12.34');
      expect(TimeText.format(9999), '9.99');
      expect(TimeText.format(59999), '59.99');
    });

    test('clamps negative input to zero instead of emitting garbage', () {
      expect(TimeText.format(-1), '0.00');
    });
  });

  group('TimeText.display', () {
    test('renders a clean time unchanged', () {
      expect(TimeText.display(timeMs: 12340), '12.34');
    });

    test('adds 2s and a trailing + for a +2', () {
      expect(TimeText.display(timeMs: 12340, isPlus2: true), '14.34+');
    });

    test('+2 can cross the minute boundary', () {
      expect(TimeText.display(timeMs: 59000, isPlus2: true), '1:01.00+');
    });

    test('DNF wins over +2 and shows no time', () {
      expect(TimeText.display(timeMs: 12340, isDnf: true), 'DNF');
      expect(
        TimeText.display(timeMs: 12340, isPlus2: true, isDnf: true),
        'DNF',
      );
    });
  });
}
