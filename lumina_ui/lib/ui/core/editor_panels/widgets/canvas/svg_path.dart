import 'dart:ui';

/// Parses SVG path data (`M 10 10 L 20 20 Z`) into a [Path]: M, L, H, V,
/// C, Q and Z in absolute and relative (lower-case) form, with implicit
/// repeats (`M 0 0 10 10` draws a line). Malformed data ends the path where
/// it breaks.
Path parseSvgPath(String data) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcQqZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?').allMatches(data).map((m) => m.group(0)!).toList();
  var i = 0;
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  String? command;
  bool isCommand(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double? next() {
    if (i >= tokens.length || isCommand(tokens[i])) return null;
    return double.tryParse(tokens[i++]);
  }

  while (i < tokens.length) {
    if (isCommand(tokens[i])) command = tokens[i++];
    final c = command;
    if (c == null) break;
    final rel = c == c.toLowerCase();
    switch (c.toUpperCase()) {
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        command = null;
        continue;
      case 'M':
        final a = next(), b = next();
        if (a == null || b == null) return path;
        x = rel ? x + a : a;
        y = rel ? y + b : b;
        startX = x;
        startY = y;
        path.moveTo(x, y);
        // Further pairs are line-tos.
        command = rel ? 'l' : 'L';
      case 'L':
        final a = next(), b = next();
        if (a == null || b == null) return path;
        x = rel ? x + a : a;
        y = rel ? y + b : b;
        path.lineTo(x, y);
      case 'H':
        final a = next();
        if (a == null) return path;
        x = rel ? x + a : a;
        path.lineTo(x, y);
      case 'V':
        final a = next();
        if (a == null) return path;
        y = rel ? y + a : a;
        path.lineTo(x, y);
      case 'C':
        final v = [for (var k = 0; k < 6; k++) next()];
        if (v.contains(null)) return path;
        final p = [for (var k = 0; k < 6; k++) v[k]! + (rel ? (k.isEven ? x : y) : 0)];
        path.cubicTo(p[0], p[1], p[2], p[3], p[4], p[5]);
        x = p[4];
        y = p[5];
      case 'Q':
        final v = [for (var k = 0; k < 4; k++) next()];
        if (v.contains(null)) return path;
        final p = [for (var k = 0; k < 4; k++) v[k]! + (rel ? (k.isEven ? x : y) : 0)];
        path.quadraticBezierTo(p[0], p[1], p[2], p[3]);
        x = p[2];
        y = p[3];
      default:
        return path;
    }
  }
  return path;
}
