import '../entities/penalty.dart';

/// WCA inspection rules, isolated so the boundaries are unit-testable without
/// running a state machine.
///
/// Regulation A3 (paraphrased): a competitor gets 15 seconds of inspection.
/// Starting the solve after 15 s but within 17 s carries a **+2**; starting
/// after 17 s is a **DNF**.
///
/// Judges call the time aloud at 8 s and 12 s — [cuePoints] mirrors that, and
/// the timer fires haptic/audio cues at the same moments.
class GradeInspection {
  const GradeInspection();

  /// Inspection allowance before any penalty.
  static const Duration limit = Duration(seconds: 15);

  /// Past this, the solve is a DNF.
  static const Duration dnfLimit = Duration(seconds: 17);

  /// Judge's calls — 8 s and 12 s elapsed.
  static const List<Duration> cuePoints = <Duration>[
    Duration(seconds: 8),
    Duration(seconds: 12),
  ];

  /// The penalty incurred by inspecting for [elapsed] before starting.
  ///
  /// The boundaries are inclusive-of-the-limit: finishing *at* exactly 15.000 s
  /// is still clean, and *at* exactly 17.000 s is still only +2. A competitor
  /// is not penalised for hitting the limit precisely — only for exceeding it.
  Penalty call(Duration elapsed) {
    if (elapsed > dnfLimit) return Penalty.dnf;
    if (elapsed > limit) return Penalty.plus2;
    return Penalty.none;
  }

  /// Whether a cue should fire on the tick that crossed from [previous] to
  /// [current]. Edge-triggered, so a cue fires exactly once however fast the
  /// ticker runs.
  bool shouldCue(Duration previous, Duration current) => cuePoints.any(
        (Duration cue) => previous < cue && current >= cue,
      );
}
