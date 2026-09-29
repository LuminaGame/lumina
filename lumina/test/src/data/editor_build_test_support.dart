import 'dart:convert';
import 'dart:io';

import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina/data/repositories/plugin_repository.dart';
import 'package:path/path.dart' as p;

/// A real temp project with `enabled_plugins: [a_plugin]` and a real temp
/// plugin package `a_plugin` (editor build tests).
class EditorBuildFixture {
  final Directory temp;
  late final Directory projectDir;
  late final Directory pluginDir;

  EditorBuildFixture._(this.temp);

  static Future<EditorBuildFixture> create({String projectName = 'HostGame', String engineRoot = ''}) async {
    final f = EditorBuildFixture._(Directory.systemTemp.createTempSync('editor_host_'));
    f.projectDir = Directory(p.join(f.temp.path, projectName))..createSync();
    File(p.join(f.projectDir.path, '$projectName.lmproject'))
        .writeAsStringSync(jsonEncode(LuminaProject(projectName: projectName, enabledPlugins: const ['a_plugin']).toMap()));
    f.pluginDir = Directory(p.join(f.projectDir.path, 'plugins', 'a_plugin'))..createSync(recursive: true);
    final api = engineRoot.isEmpty ? '../lumina_editor_api' : p.join(engineRoot, 'lumina_editor_api').replaceAll(r'\', '/');
    File(p.join(f.pluginDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: a_plugin
publish_to: none
version: 0.1.0
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  lumina_editor_api:
    path: '$api'
''');
    Directory(p.join(f.pluginDir.path, 'lib')).createSync();
    File(p.join(f.pluginDir.path, 'lib', 'a.dart')).writeAsStringSync('''
import 'package:lumina_editor_api/lumina_editor_api.dart';

class APlugin extends LuminaEditorPlugin {
  @override
  String get pluginName => 'a_plugin';

  @override
  void register(LuminaEditorContext context) {}
}
''');
    File(p.join(f.pluginDir.path, 'a_plugin.lmplugin')).writeAsStringSync(jsonEncode({
      'name': 'a_plugin',
      'friendly_name': 'A Plugin',
      'version': '0.1.0',
      'engine_version': '>=0.0.1 <1.0.0',
      'modules': [
        {'name': 'a_plugin', 'type': 'editor', 'entry_library': 'lib/a.dart', 'registration_class': 'APlugin'},
      ],
    }));
    return f;
  }

  Future<LuminaPluginDescriptor> plugin() =>
      PluginRepository(roots: []).loadInternal(File(p.join(pluginDir.path, 'a_plugin.lmplugin')), PluginOrigin.project);

  void dispose() {
    for (var i = 0; i < 20; i++) {
      try {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        sleep(const Duration(milliseconds: 250));
      }
    }
  }
}

/// Every file under [dir] (relative, `/`) with its bytes.
Map<String, List<int>> snapshot(Directory dir) => {
      for (final f in dir.listSync(recursive: true).whereType<File>())
        p.relative(f.path, from: dir.path).replaceAll(r'\', '/'): f.readAsBytesSync(),
    };
