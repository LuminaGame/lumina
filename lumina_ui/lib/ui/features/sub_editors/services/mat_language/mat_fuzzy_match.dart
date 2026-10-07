/// How a completion label matches the typed prefix, VS Code style: an
/// exact-case prefix beats a case-insensitive prefix, which beats a
/// camelCase / word-boundary match (`gwp` → `getWorldPosition`), which
/// beats a plain substring. Pure Dart.
library;

class MatMatch {
  /// 0 exact-case prefix, 1 case-insensitive prefix, 2 word boundaries, 3 substring.
  final int tier;

  /// The label's matched character indexes, for bold rendering.
  final List<int> positions;

  /// Orders matches of the same tier, lower first: for word-start matches
  /// the number of words skipped between matched ones, for substrings where
  /// the match starts.
  final int score;
  const MatMatch(this.tier, this.positions, [this.score = 0]);
}

bool _isUpper(int c) => c >= 0x41 && c <= 0x5A;
bool _isLower(int c) => c >= 0x61 && c <= 0x7A;
bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
int _lower(int c) => _isUpper(c) ? c + 0x20 : c;

/// Whether label index [i] starts a word: the first character, an upper
/// case letter after a lower case one or a digit, the first character after
/// `_`, or the first digit of a number.
bool _isBoundary(String label, int i) {
  if (i == 0) return true;
  final c = label.codeUnitAt(i);
  final p = label.codeUnitAt(i - 1);
  if (p == 0x5F) return c != 0x5F;
  if (_isUpper(c)) return _isLower(p) || _isDigit(p);
  if (_isDigit(c)) return !_isDigit(p);
  return false;
}

/// Matches [query] against [label]; null when it does not match.
MatMatch? matchLabel(String label, String query) {
  if (query.isEmpty) return const MatMatch(0, []);
  if (query.length > label.length) return null;
  final range = List<int>.generate(query.length, (i) => i);
  if (label.startsWith(query)) return MatMatch(0, range);
  final lowerLabel = label.toLowerCase();
  final lowerQuery = query.toLowerCase();
  if (lowerLabel.startsWith(lowerQuery)) return MatMatch(1, range);
  final positions = <int>[];
  if (_boundaryMatch(label, lowerQuery, 0, 0, -1, positions)) {
    var skipped = 0;
    for (var i = 0; i < positions.last; i++) {
      if (_isBoundary(label, i) && !positions.contains(i)) skipped++;
    }
    return MatMatch(2, positions, skipped);
  }
  final at = lowerLabel.indexOf(lowerQuery);
  if (at >= 0) return MatMatch(3, [for (var i = 0; i < query.length; i++) at + i], at);
  return null;
}

/// Matches query[qi..] from label[li..]: each query character either
/// continues the word matched so far or starts a later word.
bool _boundaryMatch(String label, String q, int qi, int li, int prev, List<int> out) {
  if (qi == q.length) return true;
  final want = q.codeUnitAt(qi);
  // Continue the current word.
  if (prev >= 0 && prev + 1 < label.length && _lower(label.codeUnitAt(prev + 1)) == want) {
    out.add(prev + 1);
    if (_boundaryMatch(label, q, qi + 1, prev + 2, prev + 1, out)) return true;
    out.removeLast();
  }
  // Start a later word.
  for (var i = li; i < label.length; i++) {
    if (i <= prev + 1 && prev >= 0) continue;
    if (!_isBoundary(label, i) || _lower(label.codeUnitAt(i)) != want) continue;
    out.add(i);
    if (_boundaryMatch(label, q, qi + 1, i + 1, i, out)) return true;
    out.removeLast();
  }
  return false;
}
