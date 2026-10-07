import 'package:flutter_test/flutter_test.dart';

import 'import_graph.dart';

/// The package barrels (`lumina_editor_data.dart`, `lumina_editor.dart`) are
/// for users of the package; no library inside `lib/` imports one. And the
/// data layer forms no import cycle beyond a few companion files.
void main() {
  final graph = LibImportGraph.read();
  const barrels = {'lib/lumina_editor_data.dart', 'lib/lumina_editor.dart'};

  test('no library inside lib imports a package barrel', () {
    final offenders = [
      for (final e in graph.edges.entries)
        if (!barrels.contains(e.key))
          for (final dep in e.value.where(barrels.contains)) '${e.key} -> $dep',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  // A file and its companion that import each other (a repository and the
  // reference graph it keeps, a service and the template sources it renders). Any other cycle, and any
  // cycle growing past its pair, fails.
  const companions = <Set<String>>[
    {'lib/src/repositories/asset_repository.dart', 'lib/src/services/asset_reference_graph.dart'},
    {'lib/src/services/plugin_template/code_plugin_sources.dart', 'lib/src/services/plugin_template_generator_service.dart'},
  ];

  test('the editor data layer forms no import cycle beyond its companion files', () {
    final cycles = [
      for (final c in graph.cycles())
        if (!companions.any((pair) => pair.containsAll(c))) (c.toList()..sort()).join('\n  '),
    ];
    expect(cycles, isEmpty, reason: 'cycles:\n  ${cycles.join('\n---\n  ')}');
  });
}
