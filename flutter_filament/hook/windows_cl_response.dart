/// `cl` runs through cmd.exe (after vcvars64.bat), whose command
/// line holds 8 191 characters. The wrapper's ~50 sources, ~28 include dirs
/// and ~54 Filament `.lib` inputs, each an absolute path, pass that once the
/// package sits under a longer root (a project's editor copy), so they go to a response file (`cl @file`) instead.
library;

/// The response file's content: `/I"<dir>"` per include, then each source
/// and library quoted, one per line (paths may contain spaces).
String windowsClResponse({
  required List<String> includes,
  required List<String> sources,
  required List<String> libraries,
}) =>
    [
      for (final dir in includes) '/I"${_noTrailingSlash(dir)}"',
      for (final source in sources) '"$source"',
      for (final library in libraries) '"$library"',
    ].join('\r\n');

/// The `cl` argument that reads [responseFile].
String windowsClResponseFlag(String responseFile) => '@$responseFile';

/// A trailing `\` before the closing quote would escape it.
String _noTrailingSlash(String path) {
  var p = path;
  while (p.endsWith(r'\') || p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}
