import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// The example gallery's sky material was compiled against an older
/// Filament and checked in. The engine rejected it with
/// `Material version mismatch. Expected 77 but received 75` and the sample
/// silently rendered nothing, because nothing here ever loaded it.
///
/// This walks every compiled material package in the repository and builds it
/// against the engine that is actually linked, so the next engine upgrade
/// cannot break one of them quietly.
void main() {
  List<File> materialPackages() {
    final root = Directory.current;
    return root
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.filamat'))
        .where((f) => !f.path.contains('/build/') && !f.path.contains('/.dart_tool/'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  test('the plugin compiles against the workspace engine, not a second copy of its headers', () {
    // A vendored copy of the Filament headers sat first on every
    // include path and was three material versions behind the engine the
    // static libraries were built from. Nothing failed; the plugin simply
    // compiled against a different engine than it linked, and the symptoms
    // showed up as materials that would not build and lines that would not
    // take a colour.
    final enums = File('../filament/libs/filabridge/include/filament/MaterialEnums.h');
    expect(enums.existsSync(), isTrue,
        reason: 'the workspace Filament tree is where the static libraries come from');

    final match = RegExp(r'MATERIAL_VERSION\s*=\s*(\d+)').firstMatch(enums.readAsStringSync());
    expect(match, isNotNull, reason: 'MATERIAL_VERSION not found in ${enums.path}');
    final workspaceVersion = int.parse(match!.group(1)!);

    expect(filamentExpectedMaterialVersion, workspaceVersion,
        reason: 'the plugin was compiled against headers that say '
            '$filamentExpectedMaterialVersion while the engine it links says '
            '$workspaceVersion — something is ahead of the real headers on the '
            'include path again');

    // And the copy itself must stay gone, because being first on a path is
    // how it won in the first place.
    expect(Directory('third_party/filament/include').existsSync(), isFalse,
        reason: 'a second copy of the Filament headers is back in third_party');
    expect(File('hook/build.dart').readAsStringSync(),
        isNot(matches(RegExp(r"^\s*'third_party/filament/include',", multiLine: true))),
        reason: 'the build hook is including a vendored header copy again');
  });

  test('every compiled material can be regenerated from a source', () {
    // A checked-in `.filamat` with no source and no build step cannot be
    // rebuilt when the engine moves, which is how two of them in this
    // workspace ended up compiled for an older Filament at the same time.
    // tool/materials.txt names the source and flags for each.
    final manifest = File('tool/materials.txt');
    expect(manifest.existsSync(), isTrue, reason: 'tool/materials.txt is missing');

    final rows = manifest
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map((l) => l.split('|'))
        .toList();
    expect(rows, isNotEmpty);

    for (final row in rows) {
      expect(row.length, 3, reason: 'malformed row: ${row.join('|')}');
      expect(File(row[1]).existsSync(), isTrue,
          reason: 'material source ${row[1]} does not exist');
      expect(File(row[0]).existsSync(), isTrue,
          reason: 'material output ${row[0]} has not been built');
    }

    final listed = rows.map((r) => r[0]).toSet();
    final unlisted = materialPackages()
        .map((f) => f.path.replaceFirst('${Directory.current.path}/', ''))
        .where((p) => !listed.contains(p))
        .toList();
    expect(unlisted, isEmpty,
        reason: 'these compiled materials are not in tool/materials.txt, so '
            'nothing can rebuild them:\n${unlisted.join('\n')}');
  });

  test('every checked-in .filamat loads against the linked engine', () {
    final packages = materialPackages();
    expect(packages, isNotEmpty,
        reason: 'no material packages found; the scan is looking in the wrong place');

    final expected = filamentExpectedMaterialVersion;
    // ignore: avoid_print
    print('this engine expects material version $expected');

    final engine = FilamentEngine.create(backend: FilamentBackend.noop);
    expect(engine, isNotNull);
    addTearDown(engine!.dispose);

    final failures = <String>[];
    for (final file in packages) {
      final bytes = file.readAsBytesSync();
      final relative = file.path.replaceFirst(Directory.current.path, '.');
      final version = filamentMaterialPackageVersion(bytes);

      // The version has to be checked explicitly. Loading a stale package does
      // NOT throw: the engine logs "Material version mismatch" and carries on,
      // and `fromBuffer` returns a material whose name even reads back
      // correctly, so a load-only test passes on a material that renders
      // nothing. That is exactly how a stale package once stayed hidden.
      if (version != expected) {
        failures.add('$relative is compiled for material version $version, '
            'but this engine expects $expected');
        continue;
      }

      try {
        final material = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: bytes);
        // ignore: avoid_print
        print('$relative — version $version, "${material.name}"');
        material.dispose();
      } catch (e) {
        failures.add('$relative (version $version): $e');
      }
    }

    expect(failures, isEmpty,
        reason: 'these material packages do not match this engine, so whatever '
            'uses them renders nothing:\n${failures.join('\n')}');
  });
}
