import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'import_graph.dart';

/// The package barrels (`lumina.dart`, `lumina_runtime.dart`, `testing.dart`)
/// are for users of the package. A library inside `lib/` that imports one
/// pulls every other library into a single import cycle, and then no part of
/// the engine can move to its own package.
void main() {
  final graph = LibImportGraph.read();
  const barrels = {'lib/lumina.dart', 'lib/lumina_runtime.dart', 'lib/testing.dart'};

  test('the import graph covers the package', () {
    expect(graph.edges.length, greaterThan(200));
  });

  test('no library inside lib imports a package barrel', () {
    final offenders = [
      for (final e in graph.edges.entries)
        if (!barrels.contains(e.key))
          for (final dep in e.value.where(barrels.contains)) '${e.key} -> $dep',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no import cycle runs through a barrel', () {
    final through = [
      for (final c in graph.cycles())
        if (c.any(barrels.contains)) '${c.length} libraries: ${c.where(barrels.contains).join(', ')}',
    ];
    expect(through, isEmpty, reason: through.join('\n'));
  });

  // The editor data layer lives in lumina_editor_data (its own cycle guard is
  // lumina_editor_data/test/architecture/import_cycles_test.dart) and the
  // shared formats in lumina_core; the engine keeps no lib/data, lib/domain
  // or deprecated re-export of a moved file.
  test('lib/data and lib/domain are gone and no library is a deprecated re-export', () {
    final offenders = [
      for (final e in graph.edges.entries)
        if (e.key.startsWith('lib/domain/') || e.key.startsWith('lib/data/')) e.key,
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && f.readAsStringSync().trimLeft().startsWith('@Deprecated(')) f.path,
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
