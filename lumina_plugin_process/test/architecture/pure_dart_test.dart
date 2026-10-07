import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `lumina_plugin_process` is pure Dart: nothing any of its libraries
/// reaches — its own files (the API, the runtime, the test host) and,
/// transitively, every package they import — may be Flutter, `dart:ui`, FFI,
/// the engine or the editor. That this file runs under `dart test` (no
/// Flutter) is itself part of the proof.
void main() {
  test('every library of lumina_plugin_process reaches no Flutter, dart:ui, FFI, engine or editor library', () async {
    final libDir = Directory(p.join(_packageRoot().path, 'lib'));
    final roots = [
      for (final f in libDir.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart')) f.absolute.uri,
    ];
    expect(roots.length, greaterThan(14), reason: 'the walk must cover the moved libraries');

    // Every reached library → the library that first imported it.
    final parent = <String, String?>{for (final r in roots) r.toString(): null};
    final todo = [...roots];
    final offenders = <String>[];
    var walked = 0;
    while (todo.isNotEmpty) {
      final uri = todo.removeLast();
      final file = File.fromUri(uri);
      if (!file.existsSync()) continue;
      walked++;
      final unit = parseString(content: file.readAsStringSync(), path: file.path, throwIfDiagnostics: false).unit;
      for (final d in unit.directives.whereType<UriBasedDirective>()) {
        final written = [
          d.uri.stringValue,
          if (d is NamespaceDirective) for (final c in d.configurations) c.uri.stringValue,
        ];
        for (final w in written.whereType<String>()) {
          final key = w.startsWith('dart:') || w.startsWith('package:') ? w : uri.resolve(w).toString();
          if (parent.containsKey(key)) continue;
          parent[key] = uri.toString();
          if (_forbidden(key)) {
            offenders.add(_chain(parent, key));
            continue;
          }
          if (key.startsWith('dart:')) continue;
          final resolved = key.startsWith('package:') ? await Isolate.resolvePackageUri(Uri.parse(key)) : Uri.parse(key);
          if (resolved == null) {
            offenders.add('unresolved: ${_chain(parent, key)}');
            continue;
          }
          parent[resolved.toString()] = key;
          todo.add(resolved);
        }
      }
    }
    expect(walked, greaterThan(roots.length), reason: 'the walk follows the imported packages too');
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

bool _forbidden(String uri) {
  if (uri == 'dart:ui' || uri == 'dart:ui_web' || uri == 'dart:ffi') return true;
  if (!uri.startsWith('package:')) return false;
  final package = uri.substring('package:'.length).split('/').first;
  return package == 'flutter' ||
      package.startsWith('flutter_') ||
      package == 'ffi' ||
      package == 'sky_engine' ||
      package == 'lumina' ||
      package == 'lumina_ui' ||
      package == 'lumina_editor_api' ||
      package == 'lumina_editor_data' ||
      package == 'lumina_widgets';
}

String _chain(Map<String, String?> parent, String node) =>
    [for (String? f = node; f != null; f = parent[f]) f].join(' <- ');

/// The `lumina_plugin_process` package directory (`dart test` runs from it).
Directory _packageRoot() {
  final dir = Directory.current;
  final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
  if (!pubspec.existsSync() || !pubspec.readAsStringSync().contains('name: lumina_plugin_process')) {
    throw StateError('run `dart test` from the lumina_plugin_process package directory (cwd: ${dir.path})');
  }
  return dir;
}
