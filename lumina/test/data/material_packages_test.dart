import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// A compiled `.filamat` whose header
/// version differs from the engine's is refused at load time. The engine logs
/// `Material version mismatch` and carries on, so the only symptom is that
/// whatever used the material renders nothing. Two of the three packages in
/// this workspace shipped one and nobody noticed.
///
/// A source under `../filament/` (Filament's own tree) may live in a full
/// checkout rather than in the pruned prebuilt the `filament` link points at:
/// `tool/build_materials.sh` looks in `LUMINA_FILAMENT_SRC`, `../filament` and
/// `../build/filament-src`, and so does this test.
bool _materialSourceExists(String source) {
  const vendored = '../filament/';
  if (!source.startsWith(vendored)) return File(source).existsSync();
  final relative = source.substring(vendored.length);
  final roots = [
    Platform.environment['LUMINA_FILAMENT_SRC'],
    '../filament',
    '../build/filament-src',
  ];
  return roots.whereType<String>().where((r) => r.isNotEmpty).any((r) => File('$r/$relative').existsSync());
}

void main() {
  // Paths are compared with `/` separators so a Windows checkout (`\`) filters
  // and matches the same way as a POSIX one.
  String posix(String path) => path.replaceAll('\\', '/');
  List<File> materialPackages() => Directory.current
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.filamat'))
      .where((f) => !posix(f.path).contains('/build/') && !posix(f.path).contains('/.dart_tool/'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('every compiled material can be regenerated from a source', () {
    // A checked-in `.filamat` with no source and no build step cannot be
    // rebuilt when the engine moves, which is how both of this package's
    // copies ended up compiled for an older Filament.
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
      expect(_materialSourceExists(row[1]), isTrue,
          reason: 'material source ${row[1]} does not exist (a `../filament/` source '
              'is also looked for under LUMINA_FILAMENT_SRC and ../build/filament-src, '
              'the way tool/build_materials.sh does)');
      expect(File(row[0]).existsSync(), isTrue,
          reason: 'material output ${row[0]} has not been built');
    }

    final listed = rows.map((r) => r[0]).toSet();
    final unlisted = materialPackages()
        .map((f) => posix(f.path).replaceFirst('${posix(Directory.current.path)}/', ''))
        .where((p) => !listed.contains(p))
        .toList();
    expect(unlisted, isEmpty,
        reason: 'these compiled materials are not in tool/materials.txt, so '
            'nothing can rebuild them:\n${unlisted.join('\n')}');
  });

  test('every checked-in .filamat matches the engine this package links', () {
    final packages = materialPackages();

    expect(packages, isNotEmpty,
        reason: 'no material packages found; the scan is looking in the wrong place');

    final expected = filamentExpectedMaterialVersion;
    final failures = <String>[];
    for (final file in packages) {
      final version = filamentMaterialPackageVersion(file.readAsBytesSync());
      final relative = file.path.replaceFirst(Directory.current.path, '.');
      // ignore: avoid_print
      print('$relative — material version $version');
      if (version != expected) {
        failures.add('$relative is compiled for material version $version, '
            'but this engine expects $expected');
      }
    }

    expect(failures, isEmpty,
        reason: 'these material packages render nothing against this '
            'engine:\n${failures.join('\n')}');
  });
}
