import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import '../../hook/native_library_cache.dart';

/// The machine-wide cache of the built wrapper library.
void main() {
  late Directory temp;
  late File engineCpp, toolsCpp, header, archive;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('native_cache_');
    Directory('${temp.path}/src').createSync();
    engineCpp = File('${temp.path}/src/engine_c.cpp')..writeAsStringSync('int engine() { return 1; }\n');
    toolsCpp = File('${temp.path}/src/tools_c.cpp')..writeAsStringSync('int tools() { return 2; }\n');
    header = File('${temp.path}/src/engine_c.h')..writeAsStringSync('int engine();\n');
    archive = File('${temp.path}/libfilament.a')..writeAsBytesSync(List.filled(4096, 7));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  NativeBuildInputs inputs({List<File>? sources, Map<String, String?>? defines, String arch = 'x64'}) => NativeBuildInputs(
        sources: [for (final f in sources ?? [engineCpp, toolsCpp]) f.path],
        headers: [header.path],
        archives: [archive.path],
        includes: const ['src', '../filament/filament/include'],
        defines: defines ?? const {'FLUTTER_FILAMENT_FILAMENT_VERSION': '1.77.0'},
        flags: const ['-std=c++20', '-fexceptions'],
        libraries: const ['GL'],
        targetOS: 'linux',
        targetArchitecture: arch,
        linkMode: 'dynamic_loading_bundled',
        buildMode: 'release',
        compiler: 'clang 21.1.0',
      );

  group('key', () {
    test('identical inputs give an identical key; the source order does not matter', () {
      final cache = NativeLibraryCache(root: temp);
      final a = cache.key(inputs());
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(cache.key(inputs()), a);
      expect(cache.key(inputs(sources: [toolsCpp, engineCpp])), a, reason: 'sources are sorted');
    });

    test('a byte in a source, a byte in a header, a define, the architecture and the archive mtime each change it', () {
      final cache = NativeLibraryCache(root: temp);
      final base = cache.key(inputs());

      engineCpp.writeAsStringSync('int engine() { return 3; }\n');
      expect(cache.key(inputs()), isNot(base), reason: 'engine_c.cpp');
      engineCpp.writeAsStringSync('int engine() { return 1; }\n');
      expect(cache.key(inputs()), base);

      header.writeAsStringSync('int engine(void);\n');
      expect(cache.key(inputs()), isNot(base), reason: 'a header');
      header.writeAsStringSync('int engine();\n');
      expect(cache.key(inputs()), base);

      expect(cache.key(inputs(defines: const {'FLUTTER_FILAMENT_FILAMENT_VERSION': '1.77.0', 'EXTRA': null})), isNot(base),
          reason: 'a define');
      expect(cache.key(inputs(arch: 'arm64')), isNot(base), reason: 'x64 -> arm64');

      archive.setLastModifiedSync(archive.lastModifiedSync().add(const Duration(seconds: 5)));
      expect(cache.key(inputs()), isNot(base), reason: "libfilament.a's mtime");
    });
  });

  // Every project editor builds flutter_filament from its own copy,
  // reaching the engine's archives through its own
  // `filament` link; the key must not depend on that route.
  test('an archive reached through a link keys like the same archive reached directly', () {
    final cache = NativeLibraryCache(root: temp);
    final direct = cache.key(inputs());
    final viaLinks = [
      for (final name in ['project_a', 'project_b'])
        (Link('${temp.path}/$name')..createSync(temp.path)).path,
    ];
    for (final linkRoot in viaLinks) {
      final linked = NativeBuildInputs(
        sources: ['$linkRoot/src/engine_c.cpp', '$linkRoot/src/tools_c.cpp'],
        headers: ['$linkRoot/src/engine_c.h'],
        archives: ['$linkRoot/libfilament.a'],
        includes: const ['src', '../filament/filament/include'],
        defines: const {'FLUTTER_FILAMENT_FILAMENT_VERSION': '1.77.0'},
        flags: const ['-std=c++20', '-fexceptions'],
        libraries: const ['GL'],
        targetOS: 'linux',
        targetArchitecture: 'x64',
        linkMode: 'dynamic_loading_bundled',
        buildMode: 'release',
        compiler: 'clang 21.1.0',
      );
      expect(cache.key(linked), direct, reason: linkRoot);
    }
  });

  group('publish / lookup', () {
    test('publish leaves <pkg>/<key>/<lib> and complete, and no temp directory', () async {
      final cache = NativeLibraryCache(root: temp);
      final built = File('${temp.path}/libflutter_filament.so')..writeAsBytesSync(List.generate(10000, (i) => i % 251));
      const key = 'abc123';
      await cache.publish('flutter_filament', key, built);
      final entry = Directory('${temp.path}/flutter_filament/$key');
      expect(File('${entry.path}/libflutter_filament.so').readAsBytesSync(), built.readAsBytesSync());
      expect(File('${entry.path}/complete').existsSync(), isTrue);
      expect(Directory('${temp.path}/flutter_filament').listSync().map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last),
          [key], reason: 'no *.tmp-* left behind');
      expect(cache.lookup('flutter_filament', key, 'libflutter_filament.so')!.readAsBytesSync(), built.readAsBytesSync());
    });

    test('an entry without complete (an interrupted publish) is not a hit', () {
      final cache = NativeLibraryCache(root: temp);
      final half = Directory('${temp.path}/flutter_filament/k1.tmp-123')..createSync(recursive: true);
      File('${half.path}/libflutter_filament.so').writeAsStringSync('partial');
      expect(cache.lookup('flutter_filament', 'k1', 'libflutter_filament.so'), isNull);
      final noMarker = Directory('${temp.path}/flutter_filament/k2')..createSync(recursive: true);
      File('${noMarker.path}/libflutter_filament.so').writeAsStringSync('no marker');
      expect(cache.lookup('flutter_filament', 'k2', 'libflutter_filament.so'), isNull);
    });

    test('two concurrent publishes of one key leave exactly one entry, byte-identical to the input', () async {
      final built = File('${temp.path}/lib.bin')..writeAsBytesSync(List.generate(2000000, (i) => i % 256));
      final root = temp.path;
      final builtPath = built.path;
      await Future.wait([
        for (var i = 0; i < 2; i++)
          Isolate.run(() => NativeLibraryCache(root: Directory(root)).publish('pkg', 'samekey', File(builtPath))),
      ]);
      final entries = Directory('$root/pkg').listSync().map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last).toList();
      expect(entries, ['samekey']);
      expect(File('$root/pkg/samekey/lib.bin').readAsBytesSync(), built.readAsBytesSync());
    });
  });

  // The hooks runner passes a hook only allow-listed environment variables
  // (no LUMINA_*), so a `disabled` file in the cache root is the switch that
  // always reaches the hook.
  test('a disabled file in the root switches the cache off', () {
    final cache = NativeLibraryCache(root: temp);
    expect(cache.enabled(environment: const {}), isTrue);
    expect(cache.enabled(environment: const {'LUMINA_NATIVE_CACHE': 'off'}), isFalse);
    File('${temp.path}/disabled').writeAsStringSync('');
    expect(cache.enabled(environment: const {}), isFalse);
  });

  test('the default root honours LUMINA_NATIVE_CACHE_DIR, then the platform cache folder', () {
    expect(NativeLibraryCache.defaultRoot(environment: {'LUMINA_NATIVE_CACHE_DIR': '/x/cache'}).path, '/x/cache');
    final win = NativeLibraryCache.defaultRoot(environment: {'LOCALAPPDATA': r'C:\Users\u\AppData\Local'}, operatingSystem: 'windows');
    expect(win.path.replaceAll(r'\', '/'), 'C:/Users/u/AppData/Local/lumina/native');
    final linux = NativeLibraryCache.defaultRoot(environment: {'HOME': '/home/u'}, operatingSystem: 'linux');
    expect(linux.path, '/home/u/.cache/lumina/native');
    final xdg = NativeLibraryCache.defaultRoot(environment: {'HOME': '/home/u', 'XDG_CACHE_HOME': '/xdg'}, operatingSystem: 'linux');
    expect(xdg.path, '/xdg/lumina/native');
  });
}
