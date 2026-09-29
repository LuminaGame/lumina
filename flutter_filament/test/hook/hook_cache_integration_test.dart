@Tags(['slow'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Real hook runs of a temp package that depends on
/// flutter_filament, against a temp native cache. `flutter test` in that
/// package runs the hook exactly as an app build does (and on every host,
/// where `flutter build <os>` would need a platform runner).
void main() {
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final packageRoot = Directory.current.path;
  final libName = Platform.isWindows ? 'flutter_filament.dll' : (Platform.isMacOS ? 'libflutter_filament.dylib' : 'libflutter_filament.so');

  late Directory temp, app, cacheDir;
  late Map<String, String> hookEnv;

  setUpAll(() {
    temp = Directory.systemTemp.createTempSync('hook_cache_it_');
    // The hooks runner passes a hook only allow-listed variables (no
    // LUMINA_*), so the temp cache comes from the default root's own
    // variable pointed at a temp folder; PUB_CACHE (read by the flutter tool,
    // not the hook) keeps package resolution on the real pub cache.
    final pubCache = Platform.environment['PUB_CACHE'] ??
        (Platform.isWindows ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache' : '${Platform.environment['HOME']}/.pub-cache');
    final base = Directory('${temp.path}/base')..createSync();
    if (Platform.isWindows) {
      hookEnv = {'LOCALAPPDATA': base.path, 'PUB_CACHE': pubCache};
      cacheDir = Directory('${base.path}\\lumina\\native');
    } else {
      hookEnv = {'HOME': base.path, 'PUB_CACHE': pubCache};
      cacheDir = Directory(Platform.isMacOS ? '${base.path}/Library/Caches/lumina/native' : '${base.path}/.cache/lumina/native');
    }
    app = Directory('${temp.path}/cache_probe')..createSync();
    File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: cache_probe
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  flutter_filament:
    path: ${packageRoot.replaceAll(r'\', '/')}
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
    Directory('${app.path}/test').createSync();
    File('${app.path}/test/probe_test.dart').writeAsStringSync('''
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
void main() => test('probe', () => expect(FilamentInfo.version, isNotEmpty));
''');
  });
  tearDownAll(() {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Runs the probe's `flutter test` and returns the flutter_filament hook's
  /// stdout of that run.
  Future<String> build({Map<String, String> env = const {}}) async {
    final started = DateTime.now();
    final r = await Process.run(flutter, ['test', 'test/probe_test.dart'],
        workingDirectory: app.path,
        environment: {...hookEnv, ...env},
        runInShell: Platform.isWindows);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    final logs = Directory('${app.path}/.dart_tool/hooks_runner/flutter_filament')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('stdout.txt') && f.lastModifiedSync().isAfter(started.subtract(const Duration(seconds: 2))))
        .toList();
    expect(logs, isNotEmpty, reason: 'the flutter_filament hook ran');
    return logs.map((f) => f.readAsStringSync()).join('\n');
  }

  void wipe() {
    for (final d in ['.dart_tool', 'build']) {
      final dir = Directory('${app.path}/$d');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  }

  List<String> entries() => [
        for (final e in Directory('${cacheDir.path}/flutter_filament').listSync().whereType<Directory>())
          if (!e.path.contains('.tmp-')) e.uri.pathSegments.where((s) => s.isNotEmpty).last,
      ];

  String? keyIn(String log, String verb) => RegExp('native cache $verb ([0-9a-f]{64})').firstMatch(log)?.group(1);

  final timings = <String, Duration>{};

  test('cold: store; wiped: hit with no compiler and a byte-identical library', () async {
    var sw = Stopwatch()..start();
    final cold = await build();
    timings['cold'] = sw.elapsed;
    final stored = keyIn(cold, 'store');
    expect(stored, isNotNull, reason: cold);
    expect(entries(), [stored]);

    wipe();
    sw = Stopwatch()..start();
    final warm = await build();
    timings['warm'] = sw.elapsed;
    expect(keyIn(warm, 'hit'), stored, reason: warm);
    expect(warm, isNot(contains(Platform.isWindows ? 'cl.exe' : 'clang++')), reason: 'no compiler ran on the hit');
    final bundled = Directory('${app.path}/build').listSync(recursive: true).whereType<File>().firstWhere((f) => f.path.endsWith(libName));
    expect(bundled.readAsBytesSync(), File('${cacheDir.path}/flutter_filament/$stored/$libName').readAsBytesSync());
    // ignore: avoid_print
    print('HOOK_CACHE_TIMINGS cold=${timings['cold']!.inSeconds}s warm=${timings['warm']!.inSeconds}s');
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('a source edit stores a new key; reverting it hits the original', () async {
    final tools = File('$packageRoot/src/tools_c.cpp');
    final original = tools.readAsBytesSync();
    final before = entries().single;
    try {
      tools.writeAsStringSync('${String.fromCharCodes(original)}\n// hook cache invalidation probe\n');
      final edited = await build();
      final newKey = keyIn(edited, 'store');
      expect(newKey, isNotNull, reason: edited);
      expect(newKey, isNot(before));
    } finally {
      tools.writeAsBytesSync(original);
    }
    final reverted = await build();
    expect(keyIn(reverted, 'hit'), before, reason: reverted);
  }, timeout: const Timeout(Duration(minutes: 20)));

  // LUMINA_NATIVE_CACHE=off does not reach a hook under flutter (the runner
  // filters the environment); the root's `disabled` file does.
  test('a disabled cache neither looks up nor stores', () async {
    final before = entries()..sort();
    final marker = File('${cacheDir.path}/disabled')..writeAsStringSync('');
    try {
      wipe();
      final log = await build();
      expect(log, isNot(contains('native cache')));
      expect(entries()..sort(), before);
    } finally {
      marker.deleteSync();
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
