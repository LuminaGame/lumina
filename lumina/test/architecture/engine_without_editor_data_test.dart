import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The engine's barrels reach no editor tooling. `lumina.dart` (what engine
/// users import) and `lumina_runtime.dart` (what a generated game imports)
/// are walked through every library they reach, into the packages they
/// import, and must not reach:
/// - `lumina_editor_data`, the editor data layer;
/// - the analyzer (the Blueprint function scanner), Assimp or RigLogic;
/// - the editor's repositories or a `lumina/data/` or
///   `lumina/domain/`.
void main() {
  for (final barrel in ['lumina.dart', 'lumina_runtime.dart']) {
    test('$barrel reaches no editor data layer, analyzer, Assimp or RigLogic', () {
      final walk = _ImportWalk(_PackageConfig.read());
      walk.from(Uri.parse('package:lumina/$barrel'));
      expect(walk.walked, greaterThan(200), reason: 'the walk must cover the engine');
      expect(walk.reached.keys.where((u) => u.startsWith('package:lumina_core/')), isNotEmpty,
          reason: 'the walk follows the imported packages too');
      final offenders = [for (final u in walk.reached.keys.where(_forbidden)) walk.chain(u)];
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  }
}

bool _forbidden(String uri) {
  if (!uri.startsWith('package:')) return false;
  final path = uri.substring('package:'.length);
  final package = path.split('/').first;
  return package == 'lumina_editor_data' ||
      package == 'analyzer' ||
      package == 'flutter_assimp' ||
      package == 'flutter_riglogic' ||
      path.startsWith('lumina/data/') ||
      path.startsWith('lumina/domain/') ||
      path.contains('/data/repositories/');
}

/// Follows `import` / `export` directives (conditional variants included)
/// from a library through every package it reaches. The Flutter SDK
/// packages are not entered: they cannot reach a workspace package.
class _ImportWalk {
  _ImportWalk(this.config);

  final _PackageConfig config;

  /// Reached URI (`package:…`, `dart:…`) → the URI that first reached it.
  final reached = <String, String?>{};
  var walked = 0;

  static const _sdkPackages = {'flutter', 'flutter_test', 'flutter_web_plugins', 'sky_engine', 'test_api', 'matcher'};

  void from(Uri root) {
    reached[root.toString()] = null;
    final todo = [root];
    while (todo.isNotEmpty) {
      final uri = todo.removeLast();
      if (_forbidden(uri.toString())) continue;
      final file = config.resolve(uri);
      if (file == null || !file.existsSync()) continue;
      walked++;
      final unit = parseString(content: file.readAsStringSync(), path: file.path, throwIfDiagnostics: false).unit;
      for (final d in unit.directives.whereType<NamespaceDirective>()) {
        final written = [d.uri.stringValue, for (final c in d.configurations) c.uri.stringValue];
        for (final w in written.whereType<String>()) {
          final dep = uri.resolve(w);
          final key = dep.toString();
          if (reached.containsKey(key)) continue;
          reached[key] = uri.toString();
          if (dep.scheme == 'dart') continue;
          if (_sdkPackages.contains(dep.pathSegments.first)) continue;
          todo.add(dep);
        }
      }
    }
  }

  String chain(String node) => [for (String? f = node; f != null; f = reached[f]) f].join(' <- ');
}

/// The workspace's `.dart_tool/package_config.json`.
class _PackageConfig {
  _PackageConfig(this.roots);

  /// Package name → its `lib/` directory.
  final Map<String, Directory> roots;

  factory _PackageConfig.read() {
    var dir = Directory.current.absolute;
    while (!File(p.join(dir.path, '.dart_tool', 'package_config.json')).existsSync()) {
      if (dir.parent.path == dir.path) throw StateError('no .dart_tool/package_config.json above ${Directory.current.path}');
      dir = dir.parent;
    }
    final configFile = File(p.join(dir.path, '.dart_tool', 'package_config.json'));
    final json = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final roots = <String, Directory>{};
    for (final pkg in (json['packages'] as List).cast<Map<String, dynamic>>()) {
      final rootUri = configFile.uri.resolve(_withSlash(pkg['rootUri'] as String));
      final packageUri = rootUri.resolve(_withSlash((pkg['packageUri'] as String?) ?? 'lib/'));
      roots[pkg['name'] as String] = Directory.fromUri(packageUri);
    }
    return _PackageConfig(roots);
  }

  static String _withSlash(String s) => s.endsWith('/') ? s : '$s/';

  File? resolve(Uri uri) {
    if (uri.scheme != 'package') return uri.scheme == 'file' ? File.fromUri(uri) : null;
    final segments = uri.pathSegments;
    final root = roots[segments.first];
    if (root == null) return null;
    return File(p.joinAll([root.path, ...segments.skip(1)]));
  }
}
