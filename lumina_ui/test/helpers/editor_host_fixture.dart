import 'dart:convert';
import 'dart:io';

import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;

/// A real temp project (`<temp>/<Name>/<Name>.lmproject`) that
/// enables the real temp code plugin `a_plugin` in `<project>/plugins/`, the
/// project plugin root the editor and the launcher's resolver scan.
class EditorHostFixture {
  final Directory temp;
  late final Directory projectDir;
  late final Directory pluginDir;

  EditorHostFixture._(this.temp);

  static EditorHostFixture create({String projectName = 'HostGame', List<String> enabledPlugins = const ['a_plugin']}) {
    final f = EditorHostFixture._(Directory.systemTemp.createTempSync('ui_editor_host_'));
    f.projectDir = Directory(p.join(f.temp.path, projectName))..createSync();
    File(p.join(f.projectDir.path, '$projectName.lmproject'))
        .writeAsStringSync(jsonEncode(LuminaProject(projectName: projectName, enabledPlugins: enabledPlugins).toMap()));
    f.pluginDir = Directory(p.join(f.projectDir.path, 'plugins', 'a_plugin'))..createSync(recursive: true);
    final api = LuminaWorkspace.package('lumina_editor_api').replaceAll(r'\', '/');
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

  String get hostDir => EditorHostGeneratorService.hostDirOf(projectDir.path);

  /// `flutter pub get` in the generated host (offline first).
  /// The engine source in the host, as links: a real ~650 MB
  /// copy per test is the build pipeline's and the smoke run's to prove.
  Future<void> vendorHost() => EditorSourceVendorService(engineRoot: LuminaWorkspace.root, linkPackages: true).vendorIfMissing(hostDir);

  Future<void> pubGetHost() async {
    await vendorHost();
    final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
    var r = await Process.run(flutter, ['pub', 'get', '--offline'], workingDirectory: hostDir, runInShell: Platform.isWindows);
    if (r.exitCode != 0) r = await Process.run(flutter, ['pub', 'get'], workingDirectory: hostDir, runInShell: Platform.isWindows);
    if (r.exitCode != 0) throw StateError('pub get failed in $hostDir:\n${r.stdout}\n${r.stderr}');
  }

  void dispose() {
    for (var i = 0; i < 40; i++) {
      try {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        sleep(const Duration(milliseconds: 250));
      }
    }
  }
}

/// The Flutter identity tests resolve against (no `flutter --version` probe).
Future<FlutterToolInfo> fixedFlutterInfo() async => const FlutterToolInfo('3.47.5', '6a19cca564');
