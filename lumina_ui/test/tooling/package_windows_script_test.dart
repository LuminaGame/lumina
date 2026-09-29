import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// `sh tool/package-windows.sh`, the POSIX entry point
/// (Git Bash on Windows, as `tool/ci.sh`), run for real.
void main() {
  /// Git Bash's sh.exe on Windows (next to git), `sh` elsewhere.
  String? findSh() {
    if (!Platform.isWindows) return 'sh';
    final where = Process.runSync('where', ['git'], runInShell: true);
    for (final line in (where.stdout as String).split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty)) {
      // …\Git\cmd\git.exe or …\Git\mingw64\bin\git.exe → …\Git\bin\sh.exe
      var dir = p.dirname(line.trim());
      for (var i = 0; i < 3; i++) {
        final sh = p.join(dir, 'bin', 'sh.exe');
        if (File(sh).existsSync()) return sh;
        dir = p.dirname(dir);
      }
    }
    const fallback = r'C:\Program Files\Git\bin\sh.exe';
    return File(fallback).existsSync() ? fallback : null;
  }

  /// The Flutter SDK's bin folder (dart for the script), from the test runner.
  String flutterBin() {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null && root.isNotEmpty) return p.join(root, 'bin');
    var dir = p.dirname(Platform.resolvedExecutable);
    while (p.dirname(dir) != dir) {
      if (File(p.join(dir, 'bin', Platform.isWindows ? 'flutter.bat' : 'flutter')).existsSync()) return p.join(dir, 'bin');
      dir = p.dirname(dir);
    }
    throw StateError('Flutter SDK not found from ${Platform.resolvedExecutable}');
  }

  final sh = findSh();

  Future<ProcessResult> runScript(List<String> args) {
    final env = Map<String, String>.of(Platform.environment);
    final sep = Platform.isWindows ? ';' : ':';
    env['PATH'] = '${flutterBin()}$sep${env['PATH'] ?? ''}';
    // From outside lumina_ui: the script finds its own package.
    return Process.run(sh!, [p.join(Directory.current.path, 'tool', 'package-windows.sh'), ...args],
        environment: env, workingDirectory: Directory.systemTemp.path);
  }

  test('sh tool/package-windows.sh --help exits 0 and lists --publish', () async {
    final r = await runScript(['--help']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout as String, allOf(contains('--publish'), contains('--dry-run'), contains('--skip-build')));
  }, skip: sh == null ? 'Git Bash sh.exe not found' : false, timeout: const Timeout(Duration(minutes: 3)));

  test('sh tool/package-windows.sh --dry-run prints the plan', () async {
    final r = await runScript(['--dry-run', '--skip-build']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout as String, contains('dart run msix:create'));
  }, skip: Platform.isWindows ? (sh == null ? 'Git Bash sh.exe not found' : false) : 'Windows only',
      timeout: const Timeout(Duration(minutes: 3)));

  test('off Windows, sh tool/package-windows.sh exits 2 with the Windows-only message', () async {
    final r = await runScript(const []);
    expect(r.exitCode, 2);
    expect('${r.stdout}${r.stderr}', contains('MSIX packages are built on Windows'));
  }, skip: Platform.isWindows ? 'runs off Windows (the script refuses there)' : false);
}
