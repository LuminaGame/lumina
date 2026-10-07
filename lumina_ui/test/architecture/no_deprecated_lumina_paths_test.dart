import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Lumina Studio imports the packages the engine was split into, never a
/// leftover path: every `import` / `export` of a Lumina package in its
/// `lib/`, `test/`, `integration_test/` and `tool/` files resolves, names no
/// library marked `@Deprecated`, no deep `package:lumina/data/...` or
/// `package:lumina/src/...` file and not the engine barrel
/// `package:lumina/lumina.dart` (editor code uses
/// `package:lumina_editor_data/lumina_editor.dart` or a specific package).
/// The engine itself keeps no deprecated re-export.
void main() {
  final config = _PackageConfig.read();

  test('Lumina Studio imports no deprecated, deep or removed Lumina path', () {
    final ui = config.root('lumina_ui');
    final offenders = <String>[];
    var checked = 0;
    for (final folder in ['lib', 'test', 'integration_test', 'tool', 'bin']) {
      final dir = Directory(p.join(ui.path, folder));
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final unit = parseString(content: file.readAsStringSync(), path: file.path, throwIfDiagnostics: false).unit;
        for (final d in unit.directives.whereType<NamespaceDirective>()) {
          final uris = [d.uri.stringValue, for (final c in d.configurations) c.uri.stringValue];
          for (final uri in uris.whereType<String>()) {
            if (!uri.startsWith('package:')) continue;
            final package = uri.substring('package:'.length).split('/').first;
            if (!_luminaPackages.contains(package)) continue;
            checked++;
            final where = '${p.relative(file.path, from: ui.path)}: $uri';
            final reason = _problem(config, uri);
            if (reason != null) offenders.add('$where ($reason)');
          }
        }
      }
    }
    expect(checked, greaterThan(500), reason: 'the scan must see the editor\'s imports');
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the engine package keeps no deprecated re-export of a moved file', () {
    final lib = Directory(p.join(config.root('lumina').path, 'lib'));
    expect(Directory(p.join(lib.path, 'data')).existsSync(), isFalse, reason: 'package:lumina/data/ is gone');
    final deprecated = [
      for (final f in lib.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && _isDeprecatedLibrary(f)) p.relative(f.path, from: lib.path),
    ];
    expect(deprecated, isEmpty, reason: deprecated.join('\n'));
  });
}

const _luminaPackages = {
  'lumina',
  'lumina_core',
  'lumina_editor_api',
  'lumina_editor_data',
  'lumina_widgets',
  'lumina_plugin_process',
  'lumina_plugin_protocol',
  'flutter_filament',
};

String? _problem(_PackageConfig config, String uri) {
  if (uri.startsWith('package:lumina/data/')) return 'deep path into the old engine data layer';
  if (uri.startsWith('package:lumina/src/')) return 'deep path into the engine';
  if (uri == 'package:lumina/lumina.dart') return 'the engine barrel; use lumina_editor.dart or a specific package';
  final file = config.resolve(uri);
  if (file == null || !file.existsSync()) return 'does not resolve';
  if (_isDeprecatedLibrary(file)) return 'a @Deprecated library';
  return null;
}

bool _isDeprecatedLibrary(File file) {
  final unit = parseString(content: file.readAsStringSync(), path: file.path, throwIfDiagnostics: false).unit;
  for (final d in unit.directives.whereType<LibraryDirective>()) {
    if (d.metadata.any((m) => m.name.name == 'Deprecated' || m.name.name == 'deprecated')) return true;
  }
  return false;
}

/// The workspace's `.dart_tool/package_config.json`: package → root folder.
class _PackageConfig {
  _PackageConfig(this._roots);

  final Map<String, Directory> _roots;

  factory _PackageConfig.read() {
    var dir = Directory.current.absolute;
    while (!File(p.join(dir.path, '.dart_tool', 'package_config.json')).existsSync()) {
      if (dir.parent.path == dir.path) throw StateError('no package_config.json above ${Directory.current.path}');
      dir = dir.parent;
    }
    final file = File(p.join(dir.path, '.dart_tool', 'package_config.json'));
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return _PackageConfig({
      for (final pkg in (json['packages'] as List).cast<Map<String, dynamic>>())
        pkg['name'] as String: Directory.fromUri(file.uri.resolve(_slash(pkg['rootUri'] as String))),
    });
  }

  static String _slash(String s) => s.endsWith('/') ? s : '$s/';

  Directory root(String package) => _roots[package] ?? (throw StateError('$package is not in the package config'));

  File? resolve(String uri) {
    final segments = Uri.parse(uri).pathSegments;
    final root = _roots[segments.first];
    if (root == null) return null;
    return File(p.joinAll([root.path, 'lib', ...segments.skip(1)]));
  }
}
