import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_resolver.dart';
import 'package:path/path.dart' as p;

import '../../helpers/editor_host_fixture.dart';

/// Writes the kernel plugin [name] into [projectDir]'s `plugins/`.
void _writeKernelPlugin(Directory projectDir, String name) {
  final dir = Directory(p.join(projectDir.path, 'plugins', name))..createSync(recursive: true);
  File(p.join(dir.path, '$name.lmplugin')).writeAsStringSync(jsonEncode({
    'name': name,
    'version': '1.0.0',
    'isolation': 'process',
    'modules': [
      {
        'name': name,
        'type': 'editor',
        'entry_library': 'lib/$name.dart',
        'process_class': 'KProcess',
        'process_kernel': 'bin/${name}_process.dill',
        'process_entry': 'bin/${name}_process.dart',
        'process_kernel_sdk': '3.11.0',
      },
    ],
  }));
}

/// A project whose code plugins are all kernel plugins opens without a
/// project editor build; a mixed one builds only for its compiled plugins.
void main() {
  late Directory temp;
  late EditorBuildCache cache;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('kernel_launch_');
    UserPluginDir.override = Directory(p.join(temp.path, 'user_plugins'))..createSync();
    cache = EditorBuildCache(root: Directory(p.join(temp.path, 'cache', 'editor-builds')));
  });
  tearDown(() {
    UserPluginDir.override = null;
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  test('only a kernel plugin enabled: no code plugins, so the project opens without a project editor build', () async {
    final fx = EditorHostFixture.create(projectName: 'KernelGame', enabledPlugins: const ['k_plugin']);
    addTearDown(fx.dispose);
    _writeKernelPlugin(fx.projectDir, 'k_plugin');
    final off = ProjectEditorResolver(
        engineRoot: LuminaWorkspace.root, cache: cache, flutterInfo: fixedFlutterInfo, everyProject: false);
    expect(await off.enabledCodePlugins(fx.projectDir.path), isEmpty);
    expect(await off.resolve(fx.projectDir.path), isA<OpenInPlace>());
    expect(Directory(fx.hostDir).existsSync(), isFalse, reason: 'no host is generated for a kernel plugin');
  });

  test('a built plugin-less editor stays current when a kernel plugin is enabled: no rebuild', () async {
    final fx = EditorHostFixture.create(projectName: 'KernelGame', enabledPlugins: const []);
    addTearDown(fx.dispose);
    _writeKernelPlugin(fx.projectDir, 'k_plugin');
    final resolver = ProjectEditorResolver(engineRoot: LuminaWorkspace.root, cache: cache, flutterInfo: fixedFlutterInfo);
    expect(await resolver.resolve(fx.projectDir.path), isA<NeedsBuild>(), reason: 'first build of a fresh project');
    await fx.pubGetHost();
    final components = await fingerprintComponents(await resolver.inputsFor(fx.projectDir.path, const []));
    final hash = fingerprintOf(components);
    final bundle = Directory(p.join(temp.path, 'bundle'))..createSync();
    File(p.join(bundle.path, 'kernel_game_editor.exe')).writeAsStringSync('built');
    await cache.install(hash, bundle, stamp: {'executable': 'kernel_game_editor.exe', 'inputs': components});
    expect(await resolver.resolve(fx.projectDir.path), isA<ExecCached>());

    // Enable the kernel plugin: the same build serves.
    final manifest = File(p.join(fx.projectDir.path, 'KernelGame.lmproject'));
    final json = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    json['enabled_plugins'] = ['k_plugin'];
    manifest.writeAsStringSync(jsonEncode(json));
    expect(await resolver.enabledCodePlugins(fx.projectDir.path), isEmpty);
    final d = await resolver.resolve(fx.projectDir.path);
    expect(d, isA<ExecCached>(), reason: 'a kernel plugin is no build input');
  });

  test('a mixed project builds only for its compiled plugin', () async {
    final fx = EditorHostFixture.create(projectName: 'MixedGame', enabledPlugins: const ['a_plugin', 'k_plugin']);
    addTearDown(fx.dispose);
    _writeKernelPlugin(fx.projectDir, 'k_plugin');
    final resolver = ProjectEditorResolver(engineRoot: LuminaWorkspace.root, cache: cache, flutterInfo: fixedFlutterInfo);
    final plugins = await resolver.enabledCodePlugins(fx.projectDir.path);
    expect([for (final d in plugins) d.name], ['a_plugin']);
    final d = await resolver.resolve(fx.projectDir.path);
    expect(d, isA<MissingBinary>());
    expect((d as MissingBinary).pluginNames, ['a_plugin']);
  });
}
