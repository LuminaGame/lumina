import 'dart:io';

import 'package:lumina/data/services/editor_build_fingerprint.dart';
import 'package:lumina/data/services/editor_source_vendor_service.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A project's editor builds from its own copy of the
/// engine's Dart source. A real fake workspace on disk:
///
///     a_ui → ../a_core → packages/a_native, and an override ../a_api
///     filament/ (linked, never copied)
void main() {
  late Directory temp;
  late String engine;
  late String host;

  void write(String rel, String content) {
    final f = File(p.join(engine, rel));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  String pubspec(String name, Map<String, String> deps, {Map<String, String> overrides = const {}}) {
    final b = StringBuffer('name: $name\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n');
    deps.forEach((k, v) => b.write('  $k:\n    path: $v\n'));
    if (overrides.isNotEmpty) {
      b.write('dependency_overrides:\n');
      overrides.forEach((k, v) => b.write('  $k:\n    path: $v\n'));
    }
    return b.toString();
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('vendor_');
    engine = p.join(temp.path, 'engine');
    host = p.join(temp.path, 'Game', '.lumina', 'editor');
    Directory(host).createSync(recursive: true);
    write('a_ui/pubspec.yaml', pubspec('a_ui', {'a_core': '../a_core'}, overrides: {'a_api': '../a_api'}));
    write('a_ui/lib/ui.dart', '// ui\n');
    write('a_ui/assets/logo.bin', 'LOGO');
    write('a_ui/windows/runner/main.cpp', '// runner\n');
    write('a_ui/windows/flutter/ephemeral/big.dll', 'generated');
    write('a_ui/test/ui_test.dart', '// test\n');
    write('a_ui/build/out.txt', 'build output');
    write('a_ui/.dart_tool/package_config.json', '{}');
    write('a_core/pubspec.yaml', pubspec('a_core', {'a_native': 'packages/a_native'}));
    write('a_core/lib/core.dart', '// core\n');
    write('a_core/hook/build.dart', '// hook\n');
    write('a_core/example/main.dart', '// example\n');
    write('a_core/packages/a_native/pubspec.yaml', pubspec('a_native', {}));
    write('a_core/packages/a_native/lib/native.dart', '// native\n');
    write('a_core/packages/a_native/build/big.o', 'object');
    write('a_api/pubspec.yaml', pubspec('a_api', {'a_core': '../a_core'}));
    write('a_api/lib/api.dart', '// api\n');
    write('filament/include/x.h', '#define X 1\n');
  });

  tearDown(() {
    for (var i = 0; i < 20; i++) {
      try {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        sleep(const Duration(milliseconds: 200));
      }
    }
  });

  EditorSourceVendorService service() => EditorSourceVendorService(engineRoot: engine, rootPackage: 'a_ui');

  group('closure', () {
    test('follows path dependencies and overrides, recursively', () {
      expect(service().packageClosure(), ['a_ui', 'a_core', 'a_core/packages/a_native', 'a_api']);
      expect(service().copyRoots(), ['a_ui', 'a_core', 'a_api'], reason: 'a nested package travels inside its parent');
    });

    test('a path outside the engine is an error naming the package', () {
      write('a_api/pubspec.yaml', pubspec('a_api', {'far': '../../outside'}));
      expect(() => service().packageClosure(), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('far'))));
    });

    test('the real workspace closure', () {
      final real = EditorSourceVendorService(engineRoot: LuminaWorkspace.root).packageSources();
      expect(real.keys, containsAll(['lumina_ui', 'lumina', 'flutter_filament', 'lumina_editor_api']));
      // Packages of other repos (git dependencies), copied by name from where
      // the workspace resolved them.
      for (final name in ['flutter_assimp', 'flutter_riglogic', 'flutter_gstreamer', 'lumina_smoke', 'lumina_mouse_capture', 'lumina_marketplace_shared']) {
        expect(real.keys, contains(name));
        expect(File(p.join(real[name]!, 'pubspec.yaml')).existsSync(), isTrue, reason: name);
        expect(p.isWithin(LuminaWorkspace.root, real[name]!), isFalse, reason: '$name lives in another repo');
      }
    });

    test('a git dependency is copied by name from the resolved package config', () async {
      final tools = p.join(temp.path, 'tools', 'a_tool');
      Directory(p.join(tools, 'lib')).createSync(recursive: true);
      File(p.join(tools, 'pubspec.yaml')).writeAsStringSync(pubspec('a_tool', {}));
      File(p.join(tools, 'lib', 'tool.dart')).writeAsStringSync('// tool\n');
      write('a_api/pubspec.yaml',
          'name: a_api\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n  a_tool:\n    git:\n      url: https://example.com/tools.git\n      path: a_tool\n');
      expect(() => service().packageClosure(), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('a_tool'))),
          reason: 'not resolved yet');
      write('.dart_tool/package_config.json',
          '{"configVersion": 2, "packages": [{"name": "a_tool", "rootUri": "${Uri.directory(tools)}", "packageUri": "lib/"}]}');
      expect(service().packageClosure(), ['a_ui', 'a_core', 'a_core/packages/a_native', 'a_api', 'a_tool']);
      await service().vendor(host);
      expect(File(p.join(host, 'a_tool', 'lib', 'tool.dart')).readAsStringSync(), '// tool\n');
      expect(EditorSourceVendorService.readStamp(host)!['packages'], contains('a_tool'));
      expect(await service().engineChangedSince(host), isEmpty);
      File(p.join(tools, 'lib', 'tool.dart')).writeAsStringSync('// tool v2\n');
      expect(await service().engineChangedSince(host), ['a_tool']);
    });
  });

  group('vendor', () {
    test('copies sources and assets, skips build outputs and tests, links filament, writes the stamp', () async {
      final progress = <double>[];
      await service().vendor(host, onProgress: (f, _) => progress.add(f));
      String read(String rel) => File(p.join(host, rel)).readAsStringSync();
      expect(read('a_ui/lib/ui.dart'), '// ui\n');
      expect(read('a_ui/assets/logo.bin'), 'LOGO');
      expect(read('a_ui/windows/runner/main.cpp'), '// runner\n');
      expect(read('a_core/hook/build.dart'), '// hook\n');
      expect(read('a_core/packages/a_native/lib/native.dart'), '// native\n');
      expect(read('a_api/lib/api.dart'), '// api\n');
      for (final gone in [
        'a_ui/windows/flutter/ephemeral',
        'a_ui/test',
        'a_ui/build',
        'a_ui/.dart_tool',
        'a_core/example',
        'a_core/packages/a_native/build',
      ]) {
        expect(FileSystemEntity.typeSync(p.join(host, gone)), FileSystemEntityType.notFound, reason: gone);
      }
      expect(FileSystemEntity.isLinkSync(p.join(host, 'filament')), isTrue);
      expect(read('filament/include/x.h'), '#define X 1\n', reason: 'the link resolves to the engine');
      expect(progress, isNotEmpty);
      expect(progress.last, 1.0);
      final stamp = EditorSourceVendorService.readStamp(host)!;
      expect(stamp['packages'], ['a_ui', 'a_core', 'a_api']);
      expect(stamp['engineRoot'], isNotEmpty);
      expect(service().isVendored(host), isTrue);
      Directory(p.join(host, 'a_api')).deleteSync(recursive: true);
      expect(service().isVendored(host), isFalse);
    });

    test("a release checkout's openriglogic folder is linked into the host; none without it", () async {
      await service().vendor(host);
      expect(FileSystemEntity.typeSync(p.join(host, 'openriglogic'), followLinks: false), FileSystemEntityType.notFound,
          reason: 'a source workspace has no prebuilt OpenRigLogic');

      write('openriglogic/lib/riglogic.lib', 'library');
      await service().linkOpenRigLogic(host);
      expect(FileSystemEntity.isLinkSync(p.join(host, 'openriglogic')), isTrue);
      expect(File(p.join(host, 'openriglogic', 'lib', 'riglogic.lib')).readAsStringSync(), 'library');
      if (Platform.isWindows) {
        // Junctions, not symbolic links: no admin rights or Developer Mode needed.
        for (final name in ['openriglogic', 'filament']) {
          final q = Process.runSync('fsutil', ['reparsepoint', 'query', p.join(host, name)]);
          expect('${q.stdout}'.toLowerCase(), contains('0xa0000003'), reason: name);
        }
      }

      await service().sync(host);
      expect(FileSystemEntity.isLinkSync(p.join(host, 'openriglogic')), isTrue, reason: 'vendor links it too');

      Directory(p.join(engine, 'openriglogic')).deleteSync(recursive: true);
      await service().linkOpenRigLogic(host);
      expect(FileSystemEntity.typeSync(p.join(host, 'openriglogic'), followLinks: false), FileSystemEntityType.notFound,
          reason: 'a stale link is removed');
    });

    test('an interrupted copy leaves no package behind; the next vendor completes', () async {
      var n = 0;
      await expectLater(
        service().vendor(host, onProgress: (f, _) {
          if (++n == 4) throw StateError('interrupted');
        }),
        throwsStateError,
      );
      for (final pkg in ['a_ui', 'a_core', 'a_api']) {
        expect(Directory(p.join(host, pkg)).existsSync(), isFalse, reason: pkg);
      }
      expect(service().isVendored(host), isFalse);
      await service().vendor(host);
      expect(service().isVendored(host), isTrue);
    });

    test('local edits survive vendorIfMissing; sync restores the engine and drops deleted files', () async {
      final s = service();
      await s.vendor(host);
      File(p.join(host, 'a_ui/lib/ui.dart')).writeAsStringSync('// edited in the project\n');
      expect(await s.vendorIfMissing(host), isFalse, reason: 'already vendored: nothing copied');
      expect(File(p.join(host, 'a_ui/lib/ui.dart')).readAsStringSync(), '// edited in the project\n');

      File(p.join(engine, 'a_core/lib/core.dart')).deleteSync();
      await s.sync(host);
      expect(File(p.join(host, 'a_ui/lib/ui.dart')).readAsStringSync(), '// ui\n');
      expect(File(p.join(host, 'a_core/lib/core.dart')).existsSync(), isFalse);
      expect(FileSystemEntity.isLinkSync(p.join(host, 'filament')), isTrue);
    });

    test('engineChangedSince names the repos whose content changed', () async {
      final s = service();
      await s.vendor(host);
      expect(await s.engineChangedSince(host), isEmpty);
      write('a_ui/lib/ui.dart', '// ui v2\n');
      expect(await s.engineChangedSince(host), ['a_ui']);
    });

    test('two projects copied at different times from one engine share a fingerprint; an edit to a copy names it', () async {
      final other = p.join(temp.path, 'Other', '.lumina', 'editor');
      Directory(other).createSync(recursive: true);
      await service().vendor(host);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await service().vendor(other);
      Future<Map<String, String>> components(String h) => fingerprintComponents(EditorHostInputs(
            hostDir: h,
            engineRoot: h,
            pluginDirs: const {},
            flutterVersion: '3.44.0',
            flutterRevision: 'abc',
            platform: 'windows-x64',
            mode: 'release',
            repos: service().copyRoots(),
          ));
      final a = await components(host);
      final b = await components(other);
      expect(a.keys, containsAll(['engine:a_ui', 'engine:a_core', 'engine:a_api']));
      for (final k in a.keys.where((k) => k.startsWith('engine:'))) {
        expect(b[k], a[k], reason: '$k: same content, different mtimes');
      }
      File(p.join(other, 'a_ui/lib/ui.dart')).writeAsStringSync('// ui edited\n');
      expect(diffInputs(a, await components(other)), ['editor source changed (a_ui)']);
    });

    test('a missing engine filament/ is an error naming it', () async {
      Directory(p.join(engine, 'filament')).deleteSync(recursive: true);
      await expectLater(service().vendor(host), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('filament'))));
    });
  });
}
