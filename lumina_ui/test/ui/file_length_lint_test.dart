import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No hand-written Dart file
/// under `lib/` is longer than ~1 100 lines. A growing file is split by
/// responsibility: widgets into sub-widget files, view models and big State
/// classes into `part` files with one mixin per domain (see
/// `main_editor/view_models/editor_view_model/`). Generated `*.g.dart` files
/// are exempt.
const int maxLines = 1100;
const String libDir = 'lib';
const String viewModelsDir = 'lib/ui/features/main_editor/view_models';

/// Files still over the limit, waiting for their split. This list only
/// shrinks: remove an entry when its file is split, never add one.
const Set<String> allowlist = {};

int _lineCount(File file) => file.readAsLinesSync().length;

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
    .toList();

void main() {
  test('no non-generated Dart file under lib/ exceeds $maxLines lines', () {
    final files = _dartFiles(libDir);
    expect(files, isNotEmpty, reason: 'run from the lumina_ui package root');
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

  test('no Dart file under main_editor/view_models exceeds $maxLines lines', () {
    final files = _dartFiles(viewModelsDir);
    expect(files, isNotEmpty);
    expect([
      for (final f in files)
        if (_lineCount(f) > maxLines) f.path,
    ], isEmpty);
  });

  test('editor_view_model.dart itself is at most $maxLines lines', () {
    final shell = File('$viewModelsDir/editor_view_model.dart');
    expect(shell.existsSync(), isTrue);
    expect(_lineCount(shell), lessThanOrEqualTo(maxLines));
  });
}
