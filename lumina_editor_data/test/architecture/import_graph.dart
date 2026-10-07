import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

/// The import graph of `lumina_editor_data/lib`, read with `package:analyzer`:
/// every library (a file that is not a `part of`) and the URIs its `import` /
/// `export` directives name, conditional variants included. This package's
/// own files are `lib/…`; package and SDK URIs are kept as they are.
///
/// Only real directives count: the code generators' templates write
/// `import '…';` lines inside string literals, which are not imports.
class LibImportGraph {
  LibImportGraph._(this.edges);

  static const package = 'lumina_editor_data';

  /// `lib/…` library → the URIs it imports or exports.
  final Map<String, Set<String>> edges;

  /// Reads every library under `lib/` (run from the package directory).
  factory LibImportGraph.read() {
    final edges = <String, Set<String>>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final path = p.posix.joinAll(p.split(f.path));
      final unit = parseString(content: f.readAsStringSync(), path: f.absolute.path, throwIfDiagnostics: false).unit;
      if (unit.directives.any((d) => d is PartOfDirective)) continue;
      final deps = edges[path] = <String>{};
      for (final d in unit.directives.whereType<NamespaceDirective>()) {
        final uris = [d.uri.stringValue, for (final c in d.configurations) c.uri.stringValue];
        for (final uri in uris.whereType<String>()) {
          deps.add(resolve(path, uri));
        }
      }
    }
    return LibImportGraph._(edges);
  }

  /// [uri] as written in [from] → `lib/…` for this package's files.
  static String resolve(String from, String uri) {
    if (uri.startsWith('package:$package/')) return 'lib/${uri.substring('package:$package/'.length)}';
    if (uri.contains(':')) return uri;
    return p.posix.normalize(p.posix.join(p.posix.dirname(from), uri));
  }

  /// The strongly connected components of more than one library (Tarjan).
  List<Set<String>> cycles() {
    var index = 0;
    final indices = <String, int>{};
    final low = <String, int>{};
    final stack = <String>[];
    final onStack = <String>{};
    final result = <Set<String>>[];

    void connect(String v) {
      indices[v] = low[v] = index++;
      stack.add(v);
      onStack.add(v);
      for (final w in edges[v] ?? const <String>{}) {
        if (!edges.containsKey(w)) continue;
        if (!indices.containsKey(w)) {
          connect(w);
          low[v] = low[v]! < low[w]! ? low[v]! : low[w]!;
        } else if (onStack.contains(w)) {
          low[v] = low[v]! < indices[w]! ? low[v]! : indices[w]!;
        }
      }
      if (low[v] == indices[v]) {
        final component = <String>{};
        String w;
        do {
          w = stack.removeLast();
          onStack.remove(w);
          component.add(w);
        } while (w != v);
        if (component.length > 1) result.add(component);
      }
    }

    for (final v in edges.keys) {
      if (!indices.containsKey(v)) connect(v);
    }
    return result;
  }
}
