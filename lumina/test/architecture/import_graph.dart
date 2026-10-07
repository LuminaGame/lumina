import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

/// The import graph of `lumina/lib`, read with `package:analyzer`: every
/// library (a file that is not a `part of`) and the `lib/` files its
/// `import` / `export` directives name, conditional variants included.
/// Package and SDK URIs other than `package:lumina/` are kept as they are.
class LibImportGraph {
  LibImportGraph._(this.edges);

  /// `lib/…` library → the URIs it imports or exports (`lib/…` for this
  /// package, `package:…` / `dart:…` otherwise).
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
    if (uri.startsWith('package:lumina/')) return 'lib/${uri.substring('package:lumina/'.length)}';
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

  /// Everything [roots] reach, each with the library that first reached it.
  Map<String, String?> reach(Iterable<String> roots) {
    final parent = <String, String?>{for (final r in roots) r: null};
    final todo = [...roots];
    while (todo.isNotEmpty) {
      final v = todo.removeLast();
      for (final w in edges[v] ?? const <String>{}) {
        if (parent.containsKey(w)) continue;
        parent[w] = v;
        todo.add(w);
      }
    }
    return parent;
  }

  /// `a <- b <- root` for a [reach] result.
  static String chain(Map<String, String?> parent, String node) =>
      [for (String? f = node; f != null; f = parent[f]) f].join(' <- ');
}
