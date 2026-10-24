import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The release workflow's notes come from `release_info.dart changelog`: a
/// hand-written `tool/release/notes/<tag>.md` is printed as it is, and a tag
/// without one falls back to the notes generated from the commit subjects.
void main() {
  final script = p.normalize(p.join(Directory.current.path, '..', 'tool', 'release', 'release_info.dart'));

  Future<String> changelog(String root, String tag) async {
    final result = await Process.run(
      'dart',
      [script, 'changelog', '--tag', tag, '--root', root],
      runInShell: Platform.isWindows,
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return result.stdout as String;
  }

  test('a hand-written notes file is the changelog of its tag', () async {
    final root = await Directory.systemTemp.createTemp('lumina_notes_');
    addTearDown(() => root.delete(recursive: true));
    const notes = '## What\'s Changed\n\n### New Features & Improvements\n\n- The editor opens faster.\n';
    await File(p.join(root.path, 'tool', 'release', 'notes', 'v9.9.9.md')).create(recursive: true).then((f) => f.writeAsString(notes));
    expect(await changelog(root.path, 'v9.9.9'), notes);
    expect(await changelog(root.path, 'v9.9.8'), isNot(contains('The editor opens faster.')));
    expect(await changelog(root.path, 'v9.9.8'), startsWith("## What's Changed"));
  });
}
