/// WCA-style averaging.
///
/// Pure Dart, no dependencies — the interesting logic kept easy to test and
/// identical in spirit to the native clients ("one architecture, three
/// implementations"). Times are in milliseconds; `null` represents a DNF.
///
/// Rules:
///  - `average` (ao5, ao12): drop the fastest and slowest, mean the rest.
///    For n >= 25 the fastest/slowest 5% (rounded up) are trimmed instead.
///    A DNF sorts as the slowest; if a DNF survives the trim, the average is a
///    DNF (returns `null`).
///  - `mean` (mo3, session mean): no trimming; any DNF makes the mean a DNF.
class ComputeAverages {
  const ComputeAverages();

  /// Trimmed average of the most recent [n] times, or `null` if there are
  /// fewer than [n] times or the result is a DNF.
  int? average(List<int?> timesMs, int n) {
    if (n < 3 || timesMs.length < n) return null;
    final List<int?> window = timesMs.sublist(timesMs.length - n);
    return _trimmedMean(window);
  }

  /// Untrimmed mean of the most recent [n] times, or `null` if there are fewer
  /// than [n] times or any of them is a DNF.
  int? mean(List<int?> timesMs, int n) {
    if (n < 1 || timesMs.length < n) return null;
    final List<int?> window = timesMs.sublist(timesMs.length - n);
    if (window.contains(null)) return null;
    final int sum = window.fold<int>(0, (int acc, int? t) => acc + t!);
    return (sum / window.length).round();
  }

  int? _trimmedMean(List<int?> window) {
    final int n = window.length;
    final int trim = n < 25 ? 1 : (n * 0.05).ceil();

    // Ascending; DNF (null) is treated as the largest value.
    final List<int?> sorted = List<int?>.of(window)
      ..sort((int? a, int? b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });

    final List<int?> kept = sorted.sublist(trim, n - trim);
    if (kept.contains(null)) return null; // a DNF survived the trim
    final int sum = kept.fold<int>(0, (int acc, int? t) => acc + t!);
    return (sum / kept.length).round();
  }
}
