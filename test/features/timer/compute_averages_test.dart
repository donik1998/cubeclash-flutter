import 'package:cubeclash/features/timer/domain/usecases/compute_averages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ComputeAverages avg = ComputeAverages();

  group('ao5 — drop best + worst, mean the middle 3', () {
    test('plain trimmed mean', () {
      // 10,12,14,16,18 -> drop 10 & 18 -> mean(12,14,16) = 14
      expect(avg.average(<int?>[10000, 12000, 14000, 16000, 18000], 5), 14000);
    });

    test('a single DNF is trimmed as the slowest', () {
      // 10,12,14,16,DNF -> drop 10 (best) & DNF (worst) -> mean(12,14,16) = 14
      expect(avg.average(<int?>[10000, 12000, 14000, 16000, null], 5), 14000);
    });

    test('two DNFs make the average a DNF (null)', () {
      expect(avg.average(<int?>[10000, 12000, 14000, null, null], 5), isNull);
    });

    test('uses only the most recent 5 solves', () {
      // 6 solves; the leading 100 is ignored.
      expect(
        avg.average(<int?>[100, 10000, 12000, 14000, 16000, 18000], 5),
        14000,
      );
    });

    test('returns null with fewer than 5 solves', () {
      expect(avg.average(<int?>[10000, 12000], 5), isNull);
    });
  });

  group('ao12', () {
    test('drops the single best and worst, means the middle 10', () {
      final List<int?> times = <int?>[
        5000, 9000, 9000, 9000, 9000, 9000, //
        9000, 9000, 9000, 9000, 9000, 30000,
      ];
      // drop 5000 & 30000 -> mean of ten 9000s = 9000
      expect(avg.average(times, 12), 9000);
    });
  });

  group('mean — no trimming; any DNF => DNF', () {
    test('means all values (mo3)', () {
      expect(avg.mean(<int?>[10000, 12000, 14000], 3), 12000);
    });

    test('a DNF makes the mean null', () {
      expect(avg.mean(<int?>[10000, null, 14000], 3), isNull);
    });
  });
}
