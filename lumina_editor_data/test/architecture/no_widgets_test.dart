import 'package:flutter_test/flutter_test.dart';

import 'import_graph.dart';

/// The editor data layer is data: no library of `lumina_editor_data` imports
/// a widget library (`package:flutter/widgets|material|cupertino`) or
/// shadcn_flutter. The editor's widgets live in lumina_ui.
///
/// This checks the package's own directives. The engine it imports still
/// carries the game widget layer until that moves to `lumina_widgets`.
void main() {
  final graph = LibImportGraph.read();

  test('the import graph covers the package', () {
    expect(graph.edges.length, greaterThan(35));
  });

  test('no library imports a widget library or shadcn_flutter', () {
    bool widgetLibrary(String uri) =>
        uri == 'package:flutter/widgets.dart' ||
        uri == 'package:flutter/material.dart' ||
        uri == 'package:flutter/cupertino.dart' ||
        uri.startsWith('package:flutter/src/widgets/') ||
        uri.startsWith('package:flutter/src/material/') ||
        uri.startsWith('package:flutter/src/cupertino/') ||
        uri.startsWith('package:shadcn_flutter/');
    final offenders = [
      for (final e in graph.edges.entries)
        for (final dep in e.value.where(widgetLibrary)) '${e.key} -> $dep',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
