import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Which release the installers take for "latest", from a saved
/// `GET /repos/<repo>/releases` answer: never a `filament-*` release (the
/// prebuilt Filament, published once per Filament version), never a draft,
/// never a release without the editor asset for the installer's OS.
///
/// Runs the real scripts:
/// `installer/windows/lumina-setup.ps1 -SelectReleaseFrom <file>` (Windows
/// PowerShell) and
/// `installer/linux/install-studio.sh --select-release-from <file>` (sh; Git
/// Bash on Windows).
void main() {
  final repo = Directory.current.parent.path;
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('installer_release_selection'));
  tearDown(() => temp.deleteSync(recursive: true));

  Map<String, Object?> asset(String tag, String name) => {
        'name': name,
        'size': 1024,
        'browser_download_url': 'https://github.com/LuminaGame/lumina/releases/download/$tag/$name',
      };

  Map<String, Object?> release(String tag, {bool prerelease = false, bool draft = false, required List<String> assets}) => {
        'tag_name': tag,
        'name': tag,
        'draft': draft,
        'prerelease': prerelease,
        'assets': [for (final a in assets) asset(draft ? 'untagged-0123456789abcdef' : tag, a)],
      };

  List<String> studio(String tag) => [
        'lumina-studio-$tag-windows-x64.zip',
        'lumina-studio-$tag-windows-x64.zip.sha256',
        'lumina-studio-$tag-linux-x64.tar.gz',
        'lumina-studio-$tag-linux-x64.tar.gz.sha256',
        'lumina-studio-setup-$tag-windows-x64.exe',
      ];

  final filamentRelease = release('filament-1.77.0-lumina.2', prerelease: true, assets: [
    'filament-1.77.0-lumina.2-windows-x64.zip',
    'filament-1.77.0-lumina.2-windows-x64.zip.sha256',
    'filament-1.77.0-lumina.2-linux-x64.tar.gz',
    'filament-1.77.0-lumina.2-linux-x64.tar.gz.sha256',
  ]);

  /// Newest first, as the API lists them.
  List<Map<String, Object?>> mixed() => [
        filamentRelease,
        release('v0.0.3-dev.1', prerelease: true, draft: true, assets: studio('v0.0.3-dev.1')),
        // A Lumina release whose Windows assets are missing: fine for Linux only.
        release('v0.0.2-dev.2', prerelease: true, assets: studio('v0.0.2-dev.2').where((n) => n.contains('linux')).toList()),
        release('v0.0.2-dev.1', prerelease: true, assets: studio('v0.0.2-dev.1')),
        release('v0.0.1', assets: studio('v0.0.1')),
      ];

  File save(Object json) => File(p.join(temp.path, 'releases.json'))..writeAsStringSync(jsonEncode(json));

  Map<String, String> parse(String stdout) => {
        for (final line in const LineSplitter().convert(stdout))
          if (line.contains('=')) line.substring(0, line.indexOf('=')).trim(): line.substring(line.indexOf('=') + 1).trim(),
      };

  group('lumina-setup.ps1 -SelectReleaseFrom', () {
    Future<ProcessResult> run(File json) => Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          p.join(repo, 'installer', 'windows', 'lumina-setup.ps1'),
          '-SelectReleaseFrom',
          json.path,
        ]);

    test('skips the Filament release, drafts and releases without the Windows zip', () async {
      final r = await run(save(mixed()));
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      final out = parse(r.stdout as String);
      expect(out['tag'], 'v0.0.2-dev.1');
      expect(out['asset'], 'lumina-studio-v0.0.2-dev.1-windows-x64.zip');
    });

    test('a single release object (the /releases/latest answer) works too', () async {
      final r = await run(save(release('v0.0.1', assets: studio('v0.0.1'))));
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(parse(r.stdout as String)['tag'], 'v0.0.1');
    });

    test('only a Filament release → exit 30', () async {
      final r = await run(save([filamentRelease]));
      expect(r.exitCode, 30, reason: '${r.stdout}\n${r.stderr}');
    });
  }, skip: Platform.isWindows ? false : 'Windows PowerShell only');

  /// Git Bash's sh.exe on Windows (next to git), `sh` elsewhere.
  String? findSh() {
    if (!Platform.isWindows) return 'sh';
    final where = Process.runSync('where', ['git'], runInShell: true);
    for (final line in (where.stdout as String).split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty)) {
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

  final sh = findSh();

  group('install-studio.sh --select-release-from', () {
    Future<ProcessResult> run(File json) => Process.run(
        sh!, [p.join(repo, 'installer', 'linux', 'install-studio.sh').replaceAll(r'\', '/'), '--select-release-from', json.path.replaceAll(r'\', '/')]);

    test('skips the Filament release and drafts, takes the newest with the Linux tarball', () async {
      final r = await run(save(mixed()));
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      final out = parse(r.stdout as String);
      expect(out['tag'], 'v0.0.2-dev.2');
      expect(out['asset'], 'lumina-studio-v0.0.2-dev.2-linux-x64.tar.gz');
    });

    test('a single release object (the /releases/latest answer) works too', () async {
      final r = await run(save(release('v0.0.1', assets: studio('v0.0.1'))));
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(parse(r.stdout as String)['tag'], 'v0.0.1');
    });

    test('only a Filament release → exit 30', () async {
      final r = await run(save([filamentRelease]));
      expect(r.exitCode, 30, reason: '${r.stdout}\n${r.stderr}');
    });
  }, skip: sh == null ? 'no sh (Git Bash) found' : false);
}
