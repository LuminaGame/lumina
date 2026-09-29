import 'dart:io';
import 'dart:isolate';

import 'package:lumina/data/services/editor_build_cache.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The shared cache of compiled project editors.
void main() {
  late Directory temp;
  late EditorBuildCache cache;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('editor_build_cache_');
    cache = EditorBuildCache(root: Directory(p.join(temp.path, 'editor-builds')), nativeRoot: Directory(p.join(temp.path, 'native')));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  Directory bundle(String name) {
    final d = Directory(p.join(temp.path, 'built_$name'))..createSync();
    File(p.join(d.path, 'host_game_editor.exe')).writeAsBytesSync(List.generate(4096, (i) => i % 251));
    Directory(p.join(d.path, 'data')).createSync();
    File(p.join(d.path, 'data', 'app.so')).writeAsStringSync(name);
    return d;
  }

  test('install then lookup returns the complete entry with its stamp and executable', () async {
    final entry = await cache.install('h1', bundle('a'), stamp: {'mode': 'release', 'executable': 'host_game_editor.exe'});
    expect(File(p.join(entry.dir.path, 'complete')).existsSync(), isTrue);
    final hit = cache.lookup('h1')!;
    expect(hit.stamp['hash'], 'h1');
    expect(hit.stamp['mode'], 'release');
    expect(File(hit.executable).readAsBytesSync(), File(p.join(temp.path, 'built_a', 'host_game_editor.exe')).readAsBytesSync());
    expect(File(p.join(hit.bundle.path, 'data', 'app.so')).readAsStringSync(), 'a');
    expect(Directory(p.join(cache.root.path, 'h1.tmp')).existsSync(), isFalse);
  });

  test('a crashed install (a leftover <hash>.tmp) is not a hit, and the next install cleans it', () async {
    final tmp = Directory(p.join(cache.root.path, 'h2.tmp'))..createSync(recursive: true);
    File(p.join(tmp.path, 'partial')).writeAsStringSync('x');
    expect(cache.lookup('h2'), isNull);
    final noMarker = Directory(p.join(cache.root.path, 'h3', 'bundle'))..createSync(recursive: true);
    File(p.join(noMarker.parent.path, 'stamp.json')).writeAsStringSync('{}');
    expect(cache.lookup('h3'), isNull, reason: 'no complete marker');

    await cache.install('h2', bundle('b'));
    expect(cache.lookup('h2'), isNotNull);
    expect(tmp.existsSync(), isFalse);
  });

  test('two concurrent obtains of one hash from two isolates build once; the second waits and finds the entry', () async {
    final root = cache.root.path;
    final built = bundle('c').path;
    final counter = File(p.join(temp.path, 'builds.txt'))..writeAsStringSync('');
    final counterPath = counter.path;
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        Isolate.run(() async {
          final c = EditorBuildCache(root: Directory(root));
          final e = await c.obtain('same', () async {
            File(counterPath).writeAsStringSync('build\n', mode: FileMode.append);
            await Future<void>.delayed(const Duration(milliseconds: 600));
            return (bundle: Directory(built), stamp: <String, dynamic>{'executable': 'host_game_editor.exe'});
          });
          return e.dir.path;
        }),
    ]);
    expect(counter.readAsLinesSync(), ['build'], reason: 'one build');
    expect(results[0], results[1]);
    expect(cache.hashes(), ['same']);
  }, skip: Platform.isWindows ? false : 'POSIX record locks are per process, so two isolates of one process never contend; two launchers are two processes');

  test('evict(keep: 2) removes the 2 least recently used, never a locked one', () async {
    for (final h in ['e1', 'e2', 'e3', 'e4']) {
      await cache.install(h, bundle(h));
    }
    final old = DateTime.now().subtract(const Duration(days: 60));
    // e1 oldest … e4 newest.
    for (var i = 0; i < 4; i++) {
      File(p.join(cache.root.path, 'e${i + 1}', 'last_used')).setLastModifiedSync(old.add(Duration(hours: i)));
    }
    final removed = await cache.evict(keep: 2);
    expect(removed..sort(), ['e1', 'e2']);
    expect(cache.hashes(), ['e3', 'e4']);
    expect(cache.lastEvictedBytes, greaterThan(8000));

    // Again with e3 made oldest and its lock held: it survives.
    await cache.install('e5', bundle('e5'));
    await cache.install('e6', bundle('e6'));
    File(p.join(cache.root.path, 'e3', 'last_used')).setLastModifiedSync(old);
    File(p.join(cache.root.path, 'e4', 'last_used')).setLastModifiedSync(old.add(const Duration(hours: 1)));
    await cache.withLock('e3', () async {
      final r = await cache.evict(keep: 2);
      expect(r, ['e4']);
    });
    expect(cache.hashes(), ['e3', 'e5', 'e6']);
  });

  test('evict keeps recently used entries even beyond keep', () async {
    for (final h in ['r1', 'r2', 'r3']) {
      await cache.install(h, bundle(h));
    }
    expect(await cache.evict(keep: 1), isEmpty, reason: 'all used today');
  });

  test('evict sweeps stale native library cache entries and crashed publishes', () async {
    final pkg = Directory(p.join(temp.path, 'native', 'flutter_filament'))..createSync(recursive: true);
    for (final k in ['k1', 'k2', 'k3']) {
      final d = Directory(p.join(pkg.path, k))..createSync();
      File(p.join(d.path, 'complete')).writeAsStringSync('complete\n');
      File(p.join(d.path, 'flutter_filament.dll')).writeAsBytesSync(List.filled(1000, 1));
    }
    Directory(p.join(pkg.path, 'k9.tmp-1-2-3')).createSync();
    // Directory mtimes cannot be set from Dart, so `unusedFor: zero` makes
    // every entry old enough; keep: 1 retains the newest, and the fresh
    // `.tmp-` (a publish that may still be running) stays.
    final removed = await cache.evict(keep: 1, unusedFor: Duration.zero);
    expect(removed.where((r) => r.startsWith('native/')).length, 2);
    expect(pkg.listSync().whereType<Directory>().where((d) => File(p.join(d.path, 'complete')).existsSync()).length, 1);
  });

  test('the default root is the platform cache folder', () {
    expect(EditorBuildCache.defaultRoot(environment: {'LOCALAPPDATA': r'C:\Users\u\AppData\Local'}, operatingSystem: 'windows').path.replaceAll(r'\', '/'),
        'C:/Users/u/AppData/Local/lumina/editor-builds');
    expect(EditorBuildCache.defaultRoot(environment: {'HOME': '/home/u'}, operatingSystem: 'linux').path.replaceAll(r'\', '/'),
        '/home/u/.cache/lumina/editor-builds');
    expect(EditorBuildCache.defaultRoot(environment: {'HOME': '/home/u', 'XDG_CACHE_HOME': '/xdg'}, operatingSystem: 'linux').path.replaceAll(r'\', '/'),
        '/xdg/lumina/editor-builds');
  });
}
