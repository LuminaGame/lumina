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
    expect(graph.edges.length, greaterThan(250));
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
  // lumina_editor_data/test/architecture/import_cycles_test.dart). What is
  // left under lib/data is the one-release `@Deprecated` re-exports of
  // lumina_core files (the level and theme ones with the engine extensions
  // their types gained).
  test('lib/data holds only deprecated lumina_core re-exports and lib/domain is gone', () {
    bool reexport(Set<String> deps) =>
        deps.any((u) => u.startsWith('package:lumina_core/src/')) &&
        deps.every((u) => u.startsWith('package:lumina_core/src/') || u.startsWith('lib/src/'));
    final offenders = [
      for (final e in graph.edges.entries)
        if (e.key.startsWith('lib/domain/') || (e.key.startsWith('lib/data/') && !reexport(e.value)))
          '${e.key} -> ${e.value.join(', ')}',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
