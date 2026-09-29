import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:path/path.dart' as p;

/// Enabling a plugin never writes into the engine checkout —
/// project plugins are compiled into each project's own editor host.
void main() {
  final ui = LuminaWorkspace.package('lumina_ui');

  test('lumina_ui/pubspec.yaml has no generated plugin block and no absolute path', () {
    final pubspec = File(p.join(ui, 'pubspec.yaml')).readAsStringSync();
    expect(pubspec, isNot(contains('# BEGIN LUMINA PLUGINS')));
    expect(pubspec, isNot(contains('# END LUMINA PLUGINS')));
    for (final line in pubspec.split('\n')) {
      final m = RegExp(r'^\s*path:\s*(.+)$').firstMatch(line);
      if (m == null) continue;
      final path = m.group(1)!.trim().replaceAll("'", '').replaceAll('"', '');
      expect(p.isAbsolute(path) || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path) || path.startsWith('/'), isFalse, reason: line);
    }
  });

  test('lib/ holds no generated plugin registrar and imports no project plugin', () {
    expect(File(p.join(ui, 'lib', 'generated', 'plugin_registrar.dart')).existsSync(), isFalse);
    for (final f in Directory(p.join(ui, 'lib')).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      expect(src, isNot(contains('package:lumina_plugin_')), reason: f.path);
      expect(src, isNot(contains('generated/plugin_registrar.dart')), reason: f.path);
    }
  });

  test('lib/ does not import test-only packages (lumina_ui compiles as a project editor dependency)', () {
    for (final f in Directory(p.join(ui, 'lib')).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      // lib/testing/ and its barrel lib/testing.dart are for tests only.
      final rel = p.split(p.relative(f.path, from: p.join(ui, 'lib')));
      if (rel.first == 'testing' || rel.join('/') == 'testing.dart') continue;
      final src = f.readAsStringSync();
      for (final dev in ['package:flutter_test/', 'package:integration_test/', "testing/smoke_artifacts.dart", 'package:lumina_smoke/flutter.dart', 'package:lumina_ui/testing.dart']) {
        expect(src, isNot(contains(dev)), reason: '${f.path} imports $dev');
      }
    }
  });
}
