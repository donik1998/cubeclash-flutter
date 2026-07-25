/// Persists the timer's last-selected event id so the screen reopens on the
/// event the user left it on rather than snapping back to 3×3.
///
/// A domain-level seam so the bloc (presentation) can depend on it without
/// reaching into the data layer; `LocalSolveStore` is the SharedPreferences
/// implementation. Kept separate from [SolveRepository] because a UI preference
/// is not solve data and the two have entirely different lifetimes.
abstract class LastEventStore {
  /// The stored event id, or `null` if none has been saved (or it was
  /// unreadable). Callers resolve `null`/invalid to a sensible default.
  Future<String?> loadLastEvent();

  /// Remembers [eventId] as the last-selected event.
  Future<void> saveLastEvent(String eventId);
}
