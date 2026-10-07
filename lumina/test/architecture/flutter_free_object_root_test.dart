import 'package:flutter_test/flutter_test.dart';

import 'import_graph.dart';

/// The root of every engine object — its key and `LuminaObject` — reaches no
/// Flutter library, so the object model can live in a pure-Dart package.
void main() {
  final graph = LibImportGraph.read();

  for (final root in ['lib/src/object/lumina_object_key.dart', 'lib/src/declarative/lumina_object.dart']) {
    test('$root reaches no package:flutter and no dart:ui', () {
      expect(graph.edges.containsKey(root), isTrue, reason: '$root is a library of the package');
      final reached = graph.reach([root]);
      final offenders = [
        for (final f in reached.keys)
          if (f.startsWith('package:flutter/') || f == 'dart:ui') LibImportGraph.chain(reached, f),
      ];
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  }
}
