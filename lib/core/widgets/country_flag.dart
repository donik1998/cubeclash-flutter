/// ISO 3166-1 alpha-2 country code → flag emoji.
///
/// Maps each letter to its Unicode regional-indicator symbol (`A` → U+1F1E6);
/// a pair of those renders as a flag. This avoids shipping ~250 flag assets.
///
/// Caveat worth knowing: some platforms (notably Windows) render regional
/// indicators as letter pairs rather than flags. Acceptable for MVP — revisit
/// with an asset set if desktop becomes a target.
String? countryCodeToFlag(String? code) {
  if (code == null) return null;
  final String upper = code.trim().toUpperCase();
  if (upper.length != 2) return null;

  const int base = 0x1F1E6; // REGIONAL INDICATOR SYMBOL LETTER A
  const int a = 0x41; // 'A'

  final List<int> runes = <int>[];
  for (final int unit in upper.codeUnits) {
    if (unit < a || unit > a + 25) return null; // not A–Z
    runes.add(base + (unit - a));
  }
  return String.fromCharCodes(runes);
}
