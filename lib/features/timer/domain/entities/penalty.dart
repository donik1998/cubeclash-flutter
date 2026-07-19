/// Solve penalty, per WCA rules.
enum Penalty {
  /// No penalty — the recorded time counts as-is.
  none,

  /// +2 seconds added to the recorded time.
  plus2,

  /// Did Not Finish — the solve does not count toward averages.
  dnf,
}
