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

  // A file and its companion that import each other (a model and its
  // summary, a service and the template sources it renders). Each stays one
  // unit when the data layer moves; any other cycle, and any cycle growing
  // past its pair, fails.
  const companions = <Set<String>>[
    {'lib/data/repositories/asset_repository.dart', 'lib/data/services/asset_reference_graph.dart'},
    {'lib/data/services/level_actor_material.dart', 'lib/data/services/level_asset_manifest.dart'},
    {'lib/data/services/plugin_template/code_plugin_sources.dart', 'lib/data/services/plugin_template_generator_service.dart'},
  ];

  test('the editor data layer (lib/data, lib/domain) forms no import cycle beyond its companion files', () {
    bool editorData(String f) => f.startsWith('lib/data/') || f.startsWith('lib/domain/');
    final cycles = [
      for (final c in graph.cycles())
        if (c.any(editorData) && !companions.any((pair) => pair.containsAll(c))) (c.toList()..sort()).join('\n  '),
    ];
    expect(cycles, isEmpty, reason: 'cycles:\n  ${cycles.join('\n---\n  ')}');
  });

  test('the editor data layer reaches the engine only one way: no cycle mixes lib/data and lib/src', () {
    final mixed = [
      for (final c in graph.cycles())
        if (c.any((f) => f.startsWith('lib/src/')) && c.any((f) => f.startsWith('lib/data/') || f.startsWith('lib/domain/')))
          '${c.length} libraries: ${(c.where((f) => !f.startsWith('lib/src/')).toList()..sort()).join(', ')}',
    ];
    expect(mixed, isEmpty, reason: mixed.join('\n'));
  });
}
