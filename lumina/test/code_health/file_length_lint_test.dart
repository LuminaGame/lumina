import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No hand-written Dart file under
/// `lib/` is longer than ~1 100 lines. A growing file is split by
/// responsibility into `part` files (one mixin per domain for a class with
/// state, one file per node category for the Blueprint libraries), keeping
/// the public API and import paths. Generated `*.g.dart` files are exempt.
const int maxLines = 1100;

/// Files still over the limit, waiting for their split. This list only
/// shrinks: remove an entry when its file is split, never add one.
const Set<String> allowlist = {};

int _lineCount(File file) => file.readAsLinesSync().length;

void main() {
  test('no non-generated Dart file under lib/ exceeds $maxLines lines', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .toList();
    expect(files, isNotEmpty, reason: 'run from the lumina package root');
    final offenders = [
      for (final f in files)
        if (!allowlist.contains(f.path) && _lineCount(f) > maxLines) '${f.path}: ${_lineCount(f)} lines',
    ];
    expect(offenders, isEmpty, reason: 'split these by responsibility');
  });

  test('every allowlisted file still exists and is still over the limit', () {
    final stale = [
      for (final path in allowlist)
        if (!File(path).existsSync() || _lineCount(File(path)) <= maxLines) path,
    ];
    expect(stale, isEmpty, reason: 'drop these from the allowlist: they were split');
  });
}
