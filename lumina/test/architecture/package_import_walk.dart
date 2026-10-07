import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

/// Follows `import` / `export` directives (conditional variants included)
/// from a library through every workspace or pub package it reaches, and
/// keeps every edge. The Flutter SDK packages are not entered: an edge into
/// one (`package:flutter/widgets.dart`) is recorded, its own imports are not.
class PackageImportWalk {
  PackageImportWalk(this.config);

  final PackageConfigRoots config;

  /// Reached URI (`package:…`, `dart:…`) → the URI that first reached it.
  final reached = <String, String?>{};

  /// Every library walked → the URIs its directives name.
  final edges = <String, Set<String>>{};

  var walked = 0;

  static const sdkPackages = {'flutter', 'flutter_test', 'flutter_web_plugins', 'sky_engine', 'test_api', 'matcher'};

  /// Walks from [root]; libraries for which [stop] is true are recorded but
  /// not entered.
  void from(Uri root, {bool Function(String uri)? stop}) {
    reached[root.toString()] = null;
    final todo = [root];
    while (todo.isNotEmpty) {
      final uri = todo.removeLast();
      if (stop?.call(uri.toString()) ?? false) continue;
      final file = config.resolve(uri);
      if (file == null || !file.existsSync()) continue;
      walked++;
      final unit = parseString(content: file.readAsStringSync(), path: file.path, throwIfDiagnostics: false).unit;
      final out = edges[uri.toString()] = <String>{};
      for (final d in unit.directives.whereType<NamespaceDirective>()) {
        final written = [d.uri.stringValue, for (final c in d.configurations) c.uri.stringValue];
        for (final w in written.whereType<String>()) {
          final dep = uri.resolve(w);
          final key = dep.toString();
          out.add(key);
          if (reached.containsKey(key)) continue;
          reached[key] = uri.toString();
          if (dep.scheme == 'dart') continue;
          if (sdkPackages.contains(dep.pathSegments.first)) continue;
          todo.add(dep);
        }
      }
    }
  }

  /// `node <- the library that reached it <- … <- root`.
  String chain(String node) => [for (String? f = node; f != null; f = reached[f]) f].join(' <- ');
}

/// The workspace's `.dart_tool/package_config.json`: package name → `lib/`.
class PackageConfigRoots {
  PackageConfigRoots(this.roots);

  final Map<String, Directory> roots;

  factory PackageConfigRoots.read() {
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
    return PackageConfigRoots(roots);
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
