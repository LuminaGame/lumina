import 'dart:convert';
import 'dart:io';

import 'package:lumina_editor_data/lumina_editor.dart';

/// Shared by the web build test and the web smoke: a real Third
/// Person project — real `flutter create`, `pub get` and template content —
/// built with `flutter build web`.

/// flutter_filament's WebAssembly module (`tool/web/build_module.sh`), found
/// through this package's resolved dependencies. Null when it is not built.
Directory? flutterFilamentWebModule() {
  // The package's own config, else the pub workspace's at the repository root.
  final config = [
    File('.dart_tool/package_config.json'),
    File('../.dart_tool/package_config.json'),
  ].where((f) => f.existsSync()).firstOrNull;
  if (config == null) return null;
  final packages = (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
  final entry = packages.cast<Map>().where((p) => p['name'] == 'flutter_filament').firstOrNull;
  if (entry == null) return null;
  final rootUri = entry['rootUri'] as String;
  final root = config.absolute.parent.uri.resolve(rootUri.endsWith('/') ? rootUri : '$rootUri/');
  final web = Directory.fromUri(root.resolve('web/'));
  return File('${web.path}/flutter_filament.wasm').existsSync() ? web : null;
}

/// Scaffolds the Third Person template into [root] and builds it for the web
/// with [module] served next to its `index.html`. Returns the project path;
/// the build is in `<project>/build/web`.
///
/// [customize] edits the scaffolded sources before the build, as a user would.
Future<String> buildThirdPersonGameForWeb(
  Directory root,
  Directory module, {
  String name = 'tp_web',
  void Function(String project)? customize,
}) async {
  final configDir = Directory('${root.path}/.config')..createSync();
  final repo = ProjectRepository(configDir: configDir);
  await repo.createProject(projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId);
  final project = '${root.path}/$name';
  for (final f in ['flutter_filament.js', 'flutter_filament.wasm']) {
    File('${module.path}/$f').copySync('$project/web/$f');
  }
  customize?.call(project);
  final build = await Process.run(
    'flutter',
    ['build', 'web', '--release', '--no-web-resources-cdn'],
    workingDirectory: project,
    runInShell: Platform.isWindows,
  );
  if (build.exitCode != 0) {
    throw StateError('flutter build web failed (${build.exitCode}):\n${build.stdout}\n${build.stderr}');
  }
  return project;
}
