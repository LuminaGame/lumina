import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// `.github/scripts/filament_release.sh notes`: the notes of the prebuilt
/// Filament's own `filament-<VERSION>` release, run for real with bash (Git
/// Bash on Windows).
void main() {
  final repo = Directory.current.parent.path;

  String? findBash() {
    if (!Platform.isWindows) return 'bash';
    final where = Process.runSync('where', ['git'], runInShell: true);
    for (final line in (where.stdout as String).split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty)) {
      var dir = p.dirname(line.trim());
      for (var i = 0; i < 3; i++) {
        final bash = p.join(dir, 'bin', 'bash.exe');
        if (File(bash).existsSync()) return bash;
        dir = p.dirname(dir);
      }
    }
    const fallback = r'C:\Program Files\Git\bin\bash.exe';
    return File(fallback).existsSync() ? fallback : null;
  }

  final bash = findBash();
  final script = p.join(repo, '.github', 'scripts', 'filament_release.sh').replaceAll(r'\', '/');

  test('notes name the version, the upstream tag, the commit and every patch', () async {
    const sha = '0123456789abcdef0123456789abcdef01234567';
    final r = await Process.run(bash!, [script, 'notes', '1.77.0-lumina.2', sha, 'LuminaGame/lumina']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final notes = r.stdout as String;
    expect(notes, contains('**1.77.0-lumina.2**'));
    expect(notes, contains('https://github.com/google/filament/releases/tag/v1.77.0'));
    expect(notes, contains('https://github.com/LuminaGame/lumina/commit/$sha'));
    final patches = Directory(p.join(repo, 'third_party', 'filament', 'patches'))
        .listSync()
        .map((e) => p.basename(e.path))
        .where((n) => n.endsWith('.patch'))
        .toList();
    expect(patches, hasLength(3));
    for (final patch in patches) {
      // One table row per patch, with its subject.
      expect(notes, matches(RegExp('^\\| `${RegExp.escape(patch)}` \\| \\S.+ \\|\$', multiLine: true)));
    }
    expect(notes, contains('Leave skinned/morphed renderables out of the SSR pass'));
    expect(notes, allOf(contains('filament-1.77.0-lumina.2-windows-x64.zip'), contains('filament-1.77.0-lumina.2-linux-x64.tar.gz')));
  }, skip: bash == null ? 'no bash (Git Bash) found' : false);

  test('an unknown command prints the usage and exits 64', () async {
    final r = await Process.run(bash!, [script, 'nope']);
    expect(r.exitCode, 64);
    expect(r.stderr as String, contains('filament_release.sh missing'));
  }, skip: bash == null ? 'no bash (Git Bash) found' : false);
}
