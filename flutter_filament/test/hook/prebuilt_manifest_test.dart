import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/filament/prebuilt_manifest.dart' as manifest;

/// tool/filament/prebuilt_manifest.txt lists what a prebuilt Filament archive
/// holds; it is derived from the hooks and must follow every change to them.
void main() {
  // flutter test runs in the package root; the lumina repo is its parent.
  final repo = Directory.current.parent;
  final hooks = manifest.hookFiles(repo);
  final entries = manifest.manifestEntries([for (final f in hooks) f.readAsStringSync()]);

  test('the checked-in manifest matches the hooks', () {
    final file = File('${repo.path}/tool/filament/prebuilt_manifest.txt');
    expect(file.readAsStringSync().replaceAll('\r\n', '\n'), manifest.renderManifest(entries),
        reason: 'run `dart tool/filament/prebuilt_manifest.dart` after changing a hook');
    expect(manifest.parseManifest(file.readAsStringSync()), entries);
  });

  test('every Filament path the hooks name is in the manifest', () {
    String covered(String path, String os) => entries
        .where((e) => e.appliesTo(os) && (e.path == path || (e.kind == 'dir' && path.startsWith('${e.path}/'))))
        .map((e) => e.path)
        .firstWhere((_) => true, orElse: () => '');
    final source = hooks.first.readAsStringSync();
    // The libraries each OS links, and the generated headers' folders.
    for (final lib in RegExp(r"'\$filament/(out/cmake-release/[^']+\.a)'").allMatches(source)) {
      expect(covered(lib.group(1)!, 'linux'), isNotEmpty, reason: lib.group(1));
    }
    for (final os in ['windows', 'linux']) {
      final out = os == 'windows' ? 'out/cmake-release-windows' : 'out/cmake-release';
      expect(covered('$out/libs/gltfio/materials/uberarchive.h', os), isNotEmpty);
      expect(covered('$out/samples/generated/resources/resources.h', os), isNotEmpty);
    }
    expect(covered('out/cmake-release-windows/filament/filament.lib', 'windows'), isNotEmpty,
        reason: 'the Windows library list is read from _windowsFilamentLibs');
    expect(covered('out/cmake-release-windows/third_party/libassimp/tnt/assimp.lib', 'windows'), isNotEmpty,
        reason: "flutter_assimp's windowsLib(...) calls are read too");
    expect(covered('android/gradle.properties', 'linux'), isNotEmpty, reason: 'the hook stamps VERSION_NAME');
    expect(covered('third_party/smol-v/source/smolv.cpp', 'windows'), isNotEmpty);
  });

  test('the wrapper reaches Filament headers only through the hook include folders', () {
    // A `#include "../…"` would resolve against the folder the checkout sits
    // in, not against filament_dir; a private header must go through a
    // public include folder ("gltfio/../../src/X.h") and be in the manifest.
    for (final f in Directory('src').listSync().whereType<File>()) {
      if (!f.path.endsWith('.cpp') && !f.path.endsWith('.h')) continue;
      for (final m in RegExp(r'#include\s+"([^"]+)"').allMatches(f.readAsStringSync())) {
        final path = m.group(1)!;
        expect(path.startsWith('../'), isFalse, reason: '${f.path}: $path');
        final private = RegExp(r'^(\w+)/\.\./\.\./src/(.+)$').firstMatch(path);
        if (private != null) {
          expect(entries.any((e) => e.kind == 'dir' && e.path == 'libs/${private.group(1)}/src'), isTrue,
              reason: '${f.path}: $path needs libs/${private.group(1)}/src in the manifest');
        }
      }
    }
  });
}
