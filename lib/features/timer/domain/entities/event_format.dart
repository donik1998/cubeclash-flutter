/// How a WCA round decides a competitor's result, and what the app shows
/// alongside it.
///
/// Source of truth is **WCA Regulations §9b** (verified against the current
/// Regulations, July 2026):
///
///   * `9b1a` — "Average of 5" for 3×3, 2×2, 4×4, 5×5, One-Handed, Clock,
///     Megaminx, Pyraminx, Skewb and Square-1.
///   * `9b2a` — "Mean of 3" for 6×6 and 7×7.
///   * `9b3a` — "Best of 3" for 3×3, 4×4 and 5×5 Blindfolded. `9b3b` also has
///     the WCA recognise a **Mean of 3** ranking for those events, computed
///     from the same three attempts but outside the competition format.
///   * `9b4a` — Fewest Moves is "Best of X" (X is 1 or 2) **or** "Mean of 3".
///   * `9b5a` — Multi-Blind is "Best of X" (X is 1, 2 or 3).
///
/// Two corrections to `PROMPT_WCA_EVENTS.md`, which was written from memory:
/// Fewest Moves is not unconditionally Mo3 (Bo1/Bo2 are equally official — we
/// take Mo3 because it is what a practising cuber tracks), and Multi-Blind is
/// "Best of X" rather than strictly Bo1.
enum EventFormat {
  /// Trimmed mean of five — drop the fastest and slowest.
  ao5,

  /// Untrimmed mean of three. Any DNF makes the whole mean a DNF.
  mo3,

  /// Best single of three. The other two do not enter the ranking.
  bo3,

  /// A single attempt decides it.
  bo1;

  /// How many attempts a competition round of this format contains.
  int get attempts => switch (this) {
        EventFormat.ao5 => 5,
        EventFormat.mo3 => 3,
        EventFormat.bo3 => 3,
        EventFormat.bo1 => 1,
      };

  /// Short label as cubers write it.
  String get label => switch (this) {
        EventFormat.ao5 => 'ao5',
        EventFormat.mo3 => 'mo3',
        EventFormat.bo3 => 'bo3',
        EventFormat.bo1 => 'bo1',
      };

  /// Long label for the event picker and the session header.
  String get description => switch (this) {
        EventFormat.ao5 => 'Average of 5',
        EventFormat.mo3 => 'Mean of 3',
        EventFormat.bo3 => 'Best of 3',
        EventFormat.bo1 => 'Best of 1',
      };

  /// The three cards under the timer, competition format first.
  ///
  /// **The decision the prompt asks for.** The cards show the competition
  /// format *and* the practice statistics, in that order, because the two
  /// answer different questions and a practice timer is asked both:
  ///
  ///   * the competition format answers "what would this round have scored" —
  ///     it is the only number that transfers to a real result, so it leads;
  ///   * `ao5`/`ao12` answer "am I getting better", which is what a solo
  ///     session is actually for. Rolling averages are the standard practice
  ///     metric across every timer a cuber has used, and dropping them for
  ///     6×6 because the WCA happens to rank it by mean would make the app
  ///     worse at the thing it is for.
  ///
  /// `best` leads every format: it is the one statistic that means the same
  /// thing in all of them.
  List<SessionStat> get sessionStats => switch (this) {
        // Ao5 already *is* the competition format, so the usual three stand.
        EventFormat.ao5 => const <SessionStat>[
            SessionStat.best,
            SessionStat.ao5,
            SessionStat.ao12,
          ],
        // 6×6, 7×7, FMC — mo3 is the round, ao5 is the practice trend. ao12 is
        // dropped rather than squeezed in: at ~3 minutes a solve, twelve
        // attempts is most of an hour and the number would almost never fill.
        EventFormat.mo3 => const <SessionStat>[
            SessionStat.best,
            SessionStat.mo3,
            SessionStat.ao5,
          ],
        // Blindfolded — `best` is the round (9b3a) and `mo3` is the ranking the
        // WCA also recognises (9b3b), so both are competition-real. `ao5` is
        // the practice number, and it is the one that survives the DNFs that
        // dominate blindfolded practice, since it trims the worst attempt.
        EventFormat.bo3 => const <SessionStat>[
            SessionStat.best,
            SessionStat.mo3,
            SessionStat.ao5,
          ],
        // Multi-Blind. Averaging attempts that may each have a different cube
        // count is meaningless, so there is nothing to average: the honest
        // cards are your best, your last, and how many you have done.
        EventFormat.bo1 => const <SessionStat>[
            SessionStat.best,
            SessionStat.last,
            SessionStat.attempts,
          ],
      };
}

/// One card in the session strip under the timer.
enum SessionStat {
  best,
  last,
  attempts,
  ao5,
  ao12,
  mo3;

  String get label => switch (this) {
        SessionStat.best => 'best',
        SessionStat.last => 'last',
        SessionStat.attempts => 'solves',
        SessionStat.ao5 => 'ao5',
        SessionStat.ao12 => 'ao12',
        SessionStat.mo3 => 'mo3',
      };

  /// Cards that are a count rather than a result — they never format as a time
  /// and they are never "not enough solves yet".
  bool get isCount => this == SessionStat.attempts;
}
