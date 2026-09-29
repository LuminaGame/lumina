import 'dart:convert';
import 'dart:io';

import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/repositories/plugin_repository.dart';
import 'package:lumina/data/services/editor_host_generator_service.dart';
import 'package:lumina/data/services/plugin_host_patcher_service.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _sha = 'c200c809d9c6848280b0af01e48938a016eb1f73';

void _plugin(Directory dir, String name, {bool manifest = true}) {
  dir.createSync(recursive: true);
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: $name\nversion: 0.1.0\n');
  if (!manifest) return;
  File(p.join(dir.path, '$name.lmplugin')).writeAsStringSync(jsonEncode({
    'name': name,
    'friendly_name': 'Built-in $name',
    'version': '0.1.0',
    'modules': [
      {'name': name, 'type': 'editor', 'entry_library': 'lib/$name.dart', 'registration_class': 'P'},
    ],
  }));
}

/// A real temp engine workspace after `pub get`: a `package_config.json`
/// resolving one plugin from a sibling checkout (a local override), one from
/// a pub-cache-shaped git checkout, and a package without a manifest; the
/// `pubspec.lock` pins the git one.
class _Workspace {
  _Workspace() : temp = Directory.systemTemp.createTempSync('lm_builtin_');
  final Directory temp;
  late final Directory root = Directory(p.join(temp.path, 'lumina'))..createSync();
  late final Directory siblingPlugin = Directory(p.join(temp.path, 'plugins', 'lumina_plugin_local'));
  late final Directory gitPlugin = Directory(p.join(temp.path, 'pub_cache', 'git', 'plugins-$_sha', 'lumina_plugin_pinned'));
  late final Directory plainPackage = Directory(p.join(temp.path, 'pub_cache', 'hosted', 'pub.dev', 'path-1.9.1'));

  void create() {
    _plugin(siblingPlugin, 'lumina_plugin_local');
    _plugin(gitPlugin, 'lumina_plugin_pinned');
    _plugin(plainPackage, 'path', manifest: false);
    final config = File(p.join(root.path, '.dart_tool', 'package_config.json'))..parent.createSync(recursive: true);
    String rel(Directory d) => p.relative(d.path, from: config.parent.path).replaceAll(r'\', '/');
    config.writeAsStringSync(jsonEncode({
      'configVersion': 2,
      'packages': [
        {'name': 'lumina_plugin_local', 'rootUri': rel(siblingPlugin), 'packageUri': 'lib/'},
        // An absolute file URI, as pub writes for the pub cache.
        {'name': 'lumina_plugin_pinned', 'rootUri': Uri.directory(gitPlugin.path).toString(), 'packageUri': 'lib/'},
        {'name': 'path', 'rootUri': Uri.directory(plainPackage.path).toString(), 'packageUri': 'lib/'},
      ],
    }));
    File(p.join(root.path, 'pubspec.lock')).writeAsStringSync('''
packages:
  lumina_plugin_local:
    dependency: "direct overridden"
    description:
      path: "../plugins/lumina_plugin_local"
      relative: true
    source: path
    version: "0.1.0"
  lumina_plugin_pinned:
    dependency: "direct dev"
    description:
      path: lumina_plugin_pinned
      ref: $_sha
      resolved-ref: "$_sha"
      url: "https://github.com/LuminaGame/plugins.git"
    source: git
    version: "0.1.0"
  path:
    dependency: transitive
    description:
      name: path
      sha256: "0000"
      url: "https://pub.dev"
    source: hosted
    version: "1.9.1"
sdks:
  dart: ">=3.12.0 <4.0.0"
''');
  }

  void dispose() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a handle for a moment.
    }
  }
}

void main() {
  late _Workspace ws;
  setUp(() => (ws = _Workspace()).create());
  tearDown(() => ws.dispose());

  test('the plugin packages of a workspace are the resolved packages that ship <name>.lmplugin', () {
    final dirs = LuminaWorkspace.pluginPackageDirs(ws.root.path);
    expect(dirs.map((d) => p.normalize(d)), [p.normalize(ws.siblingPlugin.path), p.normalize(ws.gitPlugin.path)]);
  });

  test('no package_config.json (no pub get yet): no plugin packages', () {
    File(p.join(ws.root.path, '.dart_tool', 'package_config.json')).deleteSync();
    expect(LuminaWorkspace.pluginPackageDirs(ws.root.path), isEmpty);
  });

  test('a packages scan root lists those plugins with its origin', () async {
    final scan = await PluginRepository(roots: [
      PluginScanRoot.packages(dir: ws.root, packageDirs: [for (final d in LuminaWorkspace.pluginPackageDirs(ws.root.path)) Directory(d)], origin: PluginOrigin.engine),
    ]).scanAll();
    expect(scan.errors, isEmpty);
    expect({for (final d in scan.plugins) d.name: d.origin}, {
      'lumina_plugin_local': PluginOrigin.engine,
      'lumina_plugin_pinned': PluginOrigin.engine,
    });
  });

  test('the git source of a package resolved from git, only for the checkout the lock resolved', () {
    final pinned = LuminaWorkspace.gitSourceOf(ws.root.path, 'lumina_plugin_pinned', packageDir: ws.gitPlugin.path);
    expect(pinned, isNotNull);
    expect(pinned!.url, 'https://github.com/LuminaGame/plugins.git');
    expect(pinned.path, 'lumina_plugin_pinned');
    expect(pinned.ref, _sha);
    // A path-resolved (overridden) package, or another folder of the same
    // name, is not the git checkout.
    expect(LuminaWorkspace.gitSourceOf(ws.root.path, 'lumina_plugin_local', packageDir: ws.siblingPlugin.path), isNull);
    expect(LuminaWorkspace.gitSourceOf(ws.root.path, 'lumina_plugin_pinned', packageDir: ws.siblingPlugin.path), isNull);
    expect(LuminaWorkspace.gitSourceOf(ws.root.path, 'path', packageDir: ws.plainPackage.path), isNull);
  });

  test('the editor host depends on a git-resolved built-in by its git source, and on others by path', () async {
    final engineRoot = LuminaWorkspace.root;
    final project = Directory(p.join(ws.temp.path, 'HostGame'))..createSync();
    final repo = PluginRepository(roots: const []);
    final pinned = await repo.loadInternal(File(p.join(ws.gitPlugin.path, 'lumina_plugin_pinned.lmplugin')), PluginOrigin.engine);
    final local = await repo.loadInternal(File(p.join(ws.siblingPlugin.path, 'lumina_plugin_local.lmplugin')), PluginOrigin.engine);

    final gen = EditorHostGeneratorService(engineRoot: engineRoot, platform: 'linux', workspaceRoot: ws.root.path);
    await gen.generate(project.path, [pinned, local], projectName: 'HostGame');
    final pubspec = File(p.join(project.path, '.lumina', 'editor', 'pubspec.yaml')).readAsStringSync();

    expect(
        pubspec,
        contains('  lumina_plugin_pinned:\n'
            '    git:\n'
            "      url: 'https://github.com/LuminaGame/plugins.git'\n"
            "      path: 'lumina_plugin_pinned'\n"
            "      ref: '$_sha'\n"));
    expect(pubspec, isNot(contains('pub_cache')), reason: 'never a path into the pub cache');
    expect(pubspec, contains("  lumina_plugin_local:\n    path: '${p.normalize(ws.siblingPlugin.path).replaceAll(r'\', '/')}'"));
  });

  test('the plugin host patcher writes a git-resolved plugin as its git source too', () async {
    final host = Directory(p.join(ws.temp.path, 'host'))..createSync();
    File(p.join(host.path, 'pubspec.yaml')).writeAsStringSync('name: host\ndependencies:\n  flutter:\n    sdk: flutter\n');
    final repo = PluginRepository(roots: const []);
    final pinned = await repo.loadInternal(File(p.join(ws.gitPlugin.path, 'lumina_plugin_pinned.lmplugin')), PluginOrigin.engine);
    final local = await repo.loadInternal(File(p.join(ws.siblingPlugin.path, 'lumina_plugin_local.lmplugin')), PluginOrigin.engine);

    await PluginHostPatcherService().patchPubspec(host, [pinned, local], workspaceRoot: ws.root.path);
    final pubspec = File(p.join(host.path, 'pubspec.yaml')).readAsStringSync();

    expect(
        pubspec,
        contains('  lumina_plugin_pinned:\n'
            '    git:\n'
            '      url: https://github.com/LuminaGame/plugins.git\n'
            '      path: lumina_plugin_pinned\n'
            '      ref: $_sha\n'));
    expect(pubspec, contains('  lumina_plugin_local:\n    path: ${ws.siblingPlugin.path}\n'));
  });
}

