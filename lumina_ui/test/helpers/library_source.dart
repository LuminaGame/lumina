import 'dart:io';

import 'package:path/path.dart' as p;

/// The source of the Dart library at [path] followed by each of its `part`
/// files, so a test that greps a library's source keeps working after the
/// library is split into parts.
String librarySource(String path) {
  final main = File(path).readAsStringSync();
  final buffer = StringBuffer(main);
  for (final m in RegExp(r"^part '([^']+)';", multiLine: true).allMatches(main)) {
    buffer
      ..write('\n')
      ..write(File(p.join(p.dirname(path), m.group(1)!)).readAsStringSync());
  }
  return buffer.toString();
}
