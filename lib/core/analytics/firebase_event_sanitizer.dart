/// Google Analytics for Firebase's naming and payload rules, as pure Dart.
///
/// **Why this exists as its own unit.** The app's [AnalyticsService] seam is
/// deliberately generic — call sites pass whatever `Map<String, Object?>`
/// describes the moment, including `bool`s and `null`s. Firebase is far
/// stricter: a parameter value may only be a `String` or a `num`, names are
/// length- and charset-limited, and some prefixes are reserved. Handing it a
/// `bool` or a `null` drops the parameter (or throws on some platforms), which
/// is the worst possible failure mode for analytics — the event still arrives,
/// silently missing the field you wanted to segment on.
///
/// So the rules live here, pure and unit-tested, rather than being discovered
/// in production dashboards. No Firebase import: this is a specification, and
/// keeping it dependency-free is what makes it exhaustively testable.
///
/// Limits below are Firebase's documented ones (Analytics → Events):
///   * event name — 1–40 chars, letters/digits/underscore, must start with a
///     letter, and may not use the reserved `firebase_` / `google_` / `ga_`
///     prefixes;
///   * parameter name — same charset, ≤ 40 chars;
///   * parameter value — `String` (≤ 100 chars) or `num`;
///   * at most 25 parameters per event.
class FirebaseEventSanitizer {
  const FirebaseEventSanitizer._();

  static const int maxNameLength = 40;
  static const int maxValueLength = 100;
  static const int maxParameters = 25;

  /// Prefixes Firebase reserves for itself. An event using one is rejected
  /// server-side, so it is prefixed out of the way rather than dropped —
  /// losing the event entirely would be a worse trade than renaming it.
  static const List<String> reservedPrefixes = <String>[
    'firebase_',
    'google_',
    'ga_',
  ];

  /// A Firebase-legal event name derived from [raw], or `null` if [raw] is
  /// empty (there is nothing to send).
  static String? eventName(String raw) {
    final String cleaned = _identifier(raw);
    if (cleaned.isEmpty) return null;

    for (final String prefix in reservedPrefixes) {
      if (cleaned.toLowerCase().startsWith(prefix)) {
        return _truncate('app_$cleaned', maxNameLength);
      }
    }
    return _truncate(cleaned, maxNameLength);
  }

  /// The Firebase-legal parameter map for [raw].
  ///
  /// Drops `null`s (an absent key says "not applicable" where an explicit null
  /// cannot survive the wire), converts `bool` to `1`/`0` so it stays
  /// *queryable* as a number rather than becoming an unfilterable string, and
  /// stringifies anything else. Returns `null` when nothing survives, because
  /// Firebase prefers an absent map to an empty one.
  static Map<String, Object>? parameters(Map<String, Object?> raw) {
    final Map<String, Object> out = <String, Object>{};

    for (final MapEntry<String, Object?> entry in raw.entries) {
      if (out.length >= maxParameters) break;

      final Object? value = entry.value;
      if (value == null) continue;

      final String name = _truncate(_identifier(entry.key), maxNameLength);
      if (name.isEmpty) continue;

      out[name] = _value(value);
    }

    return out.isEmpty ? null : out;
  }

  /// A single parameter value, coerced into Firebase's `String | num`.
  static Object _value(Object value) {
    // `num` first — bool is not a num in Dart, so ordering here is deliberate.
    if (value is num) return value;
    // Firebase has no boolean parameter type. 1/0 keeps it numeric, so it can
    // be averaged and filtered in BigQuery; 'true'/'false' could not be.
    if (value is bool) return value ? 1 : 0;
    return _truncate(value.toString(), maxValueLength);
  }

  /// Coerces [raw] to Firebase's identifier charset: letters, digits and
  /// underscores, starting with a letter.
  static String _identifier(String raw) {
    final StringBuffer buffer = StringBuffer();

    for (final int unit in raw.codeUnits) {
      final bool isLetter =
          (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A);
      final bool isDigit = unit >= 0x30 && unit <= 0x39;
      final bool isUnderscore = unit == 0x5F;

      buffer.write(
        isLetter || isDigit || isUnderscore ? String.fromCharCode(unit) : '_',
      );
    }

    // Must begin with a letter: a leading digit or underscore is prefixed
    // rather than stripped, so two names can't collapse into one.
    final String cleaned = buffer.toString();
    if (cleaned.isEmpty) return '';

    final int first = cleaned.codeUnitAt(0);
    final bool startsWithLetter =
        (first >= 0x41 && first <= 0x5A) || (first >= 0x61 && first <= 0x7A);
    return startsWithLetter ? cleaned : 'e_$cleaned';
  }

  static String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
