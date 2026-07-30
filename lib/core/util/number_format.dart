/// Thousands-separated integer formatting, without pulling in `intl`.
///
/// The app deliberately avoids `intl` for one grouping call — the rule is
/// fixed (comma every three digits, en-US), so a five-line helper beats a
/// dependency. Handles negatives, though nothing on the profile screen is
/// negative.
///
/// `1204 → "1,204"`, `12048 → "12,048"`, `0 → "0"`.
String groupThousands(int n) {
  final bool negative = n < 0;
  final String digits = n.abs().toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return negative ? '-$out' : out.toString();
}
