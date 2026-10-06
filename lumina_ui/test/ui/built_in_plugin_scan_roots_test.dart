import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/repositories/plugin_repository.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:path/path.dart' as p;

/// The Plugin Manager's BUILT-IN plugins are the plugin packages the engine
/// workspace resolved (the plugins repository's packages, pinned as git
/// dependencies, or their local checkout), not an `<engine>/plugins` folder.
void main() {
  late Directory temp;
  late Directory project;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lm_builtin_roots_');
    project = Directory(p.join(temp.path, 'project'))..createSync();
    UserPluginDir.override = Directory(p.join(temp.path, 'user_plugins'))..createSync();
  });

  tearDown(() {
    UserPluginDir.override = null;
    LuminaWorkspace.clearCheckout();
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a handle for a moment.
    }
  });

  Future<Map<String, PluginOrigin>> scan() async {
    final result = await PluginRepository(roots: editorPluginScanRoots(project.path)).scanAll();
    return {for (final d in result.plugins) d.name: d.origin};
  }

  test('a release checkout: plugins resolved into the pub cache are built-ins', () async {
    // What EngineBootstrap leaves: the lumina checkout after `pub get`, its
    // plugins in the pub cache's git folder.
    final checkout = Directory(p.join(temp.path, 'engine', '0.0.1'))..createSync(recursive: true);
    final cache = Directory(p.join(temp.path, 'pub_cache', 'git', 'plugins-c200c809d9c6848280b0af01e48938a016eb1f73'));
    final packages = <Map<String, String>>[];
    for (final name in ['lumina_plugin_pcg', 'lumina_plugin_miniai']) {
      final dir = Directory(p.join(cache.path, name))..createSync(recursive: true);
      File(p.join(dir.path, '$name.lmplugin')).writeAsStringSync(jsonEncode({
        'name': name,
        'version': '0.1.0',
        'modules': [
          {'name': name, 'type': 'editor', 'entry_library': 'lib/$name.dart', 'registration_class': 'P'},
        ],
      }));
      packages.add({'name': name, 'rootUri': Uri.directory(dir.path).toString(), 'packageUri': 'lib/'});
    }
    File(p.join(checkout.path, '.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'configVersion': 2, 'packages': packages}));
    LuminaWorkspace.useCheckout(checkout.path, commit: 'abc', repo: kLuminaGitUrl);

    expect(await scan(), {'lumina_plugin_miniai': PluginOrigin.engine, 'lumina_plugin_pcg': PluginOrigin.engine});
  });

  test('this source workspace: the plugins it depends on are built-ins', () async {
    final names = [for (final d in LuminaWorkspace.pluginPackageDirs(LuminaWorkspace.root)) p.basename(d)];
    if (names.isEmpty) {
      markTestSkipped('no plugin packages resolved in ${LuminaWorkspace.root} (run pub get)');
      return;
    }
    final found = await scan();
    expect(found['lumina_plugin_pcg'], PluginOrigin.engine);
    expect(found['lumina_plugin_miniai'], PluginOrigin.engine);
  });

  test('a project plugin of the same name still wins over the built-in', () async {
    final dir = Directory(p.join(project.path, 'plugins', 'lumina_plugin_pcg'))..createSync(recursive: true);
    File(p.join(dir.path, 'lumina_plugin_pcg.lmplugin')).writeAsStringSync(jsonEncode({
      'name': 'lumina_plugin_pcg',
      'version': '9.0.0',
      'modules': [
        {'name': 'lumina_plugin_pcg', 'type': 'editor', 'entry_library': 'lib/lumina_plugin_pcg.dart', 'registration_class': 'P'},
      ],
    }));
    if (LuminaWorkspace.pluginPackageDirs(LuminaWorkspace.root).isEmpty) {
      markTestSkipped('no plugin packages resolved in ${LuminaWorkspace.root} (run pub get)');
      return;
    }
    expect((await scan())['lumina_plugin_pcg'], PluginOrigin.project);
  });

  test("a project path with mixed separators gives project plugins a normalised folder", () async {
    final plugin = Directory(p.join(project.path, 'plugins', 'mixed_plugin'))..createSync(recursive: true);
    File(p.join(plugin.path, 'mixed_plugin.lmplugin')).writeAsStringSync(jsonEncode({
      'name': 'mixed_plugin',
      'version': '0.1.0',
      'modules': [
        {'name': 'mixed_plugin', 'type': 'editor', 'entry_library': 'lib/mixed_plugin.dart', 'registration_class': 'P'},
      ],
    }));
    // As the editor may hold it: `/` joined onto a platform path, a `.` segment.
    final mixed = '${temp.path}/./project';
    final result = await PluginRepository(roots: editorPluginScanRoots(mixed)).scanAll();
    final found = result.plugins.firstWhere((d) => d.name == 'mixed_plugin');
    expect(found.origin, PluginOrigin.project);
    expect(found.pluginDir.path, p.normalize(plugin.path));
  });
}
