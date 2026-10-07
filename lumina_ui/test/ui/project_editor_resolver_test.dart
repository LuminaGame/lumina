import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_resolver.dart';
import 'package:path/path.dart' as p;

import '../helpers/editor_host_fixture.dart';

/// How the launcher opens a project — in place, in its cached
/// project editor, after a build, or after the missing-binary prompt.
void main() {
  late EditorHostFixture fx;
  late EditorBuildCache cache;
  late ProjectEditorResolver resolver;

  setUp(() {
    fx = EditorHostFixture.create();
    UserPluginDir.override = Directory(p.join(fx.temp.path, 'user_plugins'))..createSync();
    cache = EditorBuildCache(root: Directory(p.join(fx.temp.path, 'cache', 'editor-builds')));
    resolver = ProjectEditorResolver(engineRoot: LuminaWorkspace.root, cache: cache, flutterInfo: fixedFlutterInfo);
  });
  tearDown(() {
    UserPluginDir.override = null;
    fx.dispose();
  });

  // Every project opens in its own project editor.
  test('a project without code plugins and no host: the host is generated, then a first build', () async {
    final plain = EditorHostFixture.create(projectName: 'PlainGame', enabledPlugins: const []);
    addTearDown(plain.dispose);
    final d = await resolver.resolve(plain.projectDir.path);
    expect(d, isA<NeedsBuild>());
    expect((d as NeedsBuild).reason, contains('first build'));
    expect(d.plugins, isEmpty);
    expect(File(p.join(plain.hostDir, 'pubspec.yaml')).existsSync(), isTrue);
    expect(File(p.join(plain.hostDir, 'lib', 'plugin_registrar.dart')).existsSync(), isTrue);
  });

  test('per-project editors off (Editor Preferences): a plugin-less project opens in place, its host untouched', () async {
    final plain = EditorHostFixture.create(projectName: 'PlainGame', enabledPlugins: const []);
    addTearDown(plain.dispose);
    final off = ProjectEditorResolver(engineRoot: LuminaWorkspace.root, cache: cache, flutterInfo: fixedFlutterInfo, everyProject: false);
    expect(await off.resolve(plain.projectDir.path), isA<OpenInPlace>());
    expect(Directory(plain.hostDir).existsSync(), isFalse, reason: 'nothing generated');
    await off.generator.generate(plain.projectDir.path, const []);
    expect(await off.resolve(plain.projectDir.path), isA<OpenInPlace>());
    expect(Directory(plain.hostDir).existsSync(), isTrue, reason: 'an existing host is left alone');
    // A code-plugin project is unaffected by the switch.
    expect(await off.resolve(fx.projectDir.path), isA<MissingBinary>());
  });

  test('plugin-less projects: a built fingerprint → execCached, and two such projects share one cache entry', () async {
    final a = EditorHostFixture.create(projectName: 'PlainA', enabledPlugins: const []);
    final b = EditorHostFixture.create(projectName: 'PlainB', enabledPlugins: const []);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    for (final f in [a, b]) {
      expect(await resolver.resolve(f.projectDir.path), isA<NeedsBuild>());
      await f.pubGetHost();
    }
    final ha = fingerprintOf(await fingerprintComponents(await resolver.inputsFor(a.projectDir.path, const [])));
    final hb = fingerprintOf(await fingerprintComponents(await resolver.inputsFor(b.projectDir.path, const [])));
    expect(hb, ha, reason: 'same engine, Flutter, platform, mode and (no) plugins');

    final bundle = Directory(p.join(fx.temp.path, 'plain_bundle'))..createSync();
    File(p.join(bundle.path, 'plain_a_editor.exe')).writeAsStringSync('built');
    await cache.install(ha, bundle, stamp: {'executable': 'plain_a_editor.exe'});
    expect(await resolver.resolve(a.projectDir.path), isA<ExecCached>());
    expect(await resolver.resolve(b.projectDir.path), isA<ExecCached>(), reason: "B reuses A's build");
  });

  // The editor builds from a copy of the engine source inside
  // the project.
  test('a host without the source copy → needsBuild saying it will be copied; with it → the usual reasons', () async {
    final plugins = await resolver.enabledCodePlugins(fx.projectDir.path);
    await resolver.generator.generate(fx.projectDir.path, plugins);
    final d = await resolver.resolve(fx.projectDir.path);
    expect(d, isA<NeedsBuild>());
    expect((d as NeedsBuild).reason, 'the editor source is not in the project yet (about 650 MB will be copied)');
    await fx.vendorHost();
    expect(((await resolver.resolve(fx.projectDir.path)) as NeedsBuild).reason, 'not built on this machine yet');
  });

  test('an old-layout host (absolute engine path) → needsBuild "editor source copied into the project", migrated', () async {
    Directory(fx.hostDir).createSync(recursive: true);
    File(p.join(fx.hostDir, 'pubspec.yaml')).writeAsStringSync(
        "name: host_game_editor\ndependencies:\n  lumina_ui:\n    path: '${p.join(LuminaWorkspace.root, 'lumina_ui').replaceAll(r'\', '/')}'\n");
    File(p.join(fx.hostDir, 'pubspec.lock')).writeAsStringSync('packages: {}\n');
    final d = await resolver.resolve(fx.projectDir.path);
    expect(d, isA<NeedsBuild>());
    expect((d as NeedsBuild).reason, 'editor source copied into the project');
    expect(File(p.join(fx.hostDir, 'pubspec.yaml')).readAsStringSync(), contains('  lumina_ui:\n    path: lumina_ui\n'));
    expect(File(p.join(fx.hostDir, 'pubspec.lock')).readAsStringSync(), isNot('packages: {}\n'),
        reason: "the old resolution is dropped; the engine lock's versions seed the new one");
  });

  test('enabled_plugins set but .lumina/editor absent → missingBinary naming the plugin', () async {
    final d = await resolver.resolve(fx.projectDir.path);
    expect(d, isA<MissingBinary>());
    expect((d as MissingBinary).pluginNames, ['a_plugin']);
    expect(d.reason, isNotEmpty);
  });

  test('a host whose fingerprint is cached → execCached; a plugin edit after the build → needsBuild naming it', () async {
    final plugins = await resolver.enabledCodePlugins(fx.projectDir.path);
    expect([for (final d in plugins) d.name], ['a_plugin']);
    await resolver.generator.generate(fx.projectDir.path, plugins);
    expect(await resolver.resolve(fx.projectDir.path), isA<NeedsBuild>(), reason: 'generated but never resolved/built');
    await fx.pubGetHost();

    // What EditorBuildService writes after a build: the entry and the stamp.
    final components = await fingerprintComponents(await resolver.inputsFor(fx.projectDir.path, plugins));
    final hash = fingerprintOf(components);
    final bundle = Directory(p.join(fx.temp.path, 'bundle'))..createSync();
    File(p.join(bundle.path, 'host_game_editor.exe')).writeAsStringSync('built');
    await cache.install(hash, bundle, stamp: {'executable': 'host_game_editor.exe', 'inputs': components});
    File(p.join(fx.hostDir, EditorHostGeneratorService.stampFileName))
        .writeAsStringSync(jsonEncode({'hash': hash, 'inputs': components}));

    final hit = await resolver.resolve(fx.projectDir.path);
    expect(hit, isA<ExecCached>());
    expect((hit as ExecCached).entry.hash, hash);
    expect(p.basename(hit.entry.executable), 'host_game_editor.exe');

    final a = File(p.join(fx.pluginDir.path, 'lib', 'a.dart'));
    a.writeAsStringSync('${a.readAsStringSync()}// edited after the build\n');
    final stale = await resolver.resolve(fx.projectDir.path);
    expect(stale, isA<NeedsBuild>());
    expect((stale as NeedsBuild).reason, 'plugin a_plugin changed');

    expect(await resolver.resolve(fx.projectDir.path, rebuild: true), isA<NeedsBuild>());
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('two projects with the same plugins on the same engine share one cache entry', () async {
    // a_plugin installed once for the user (~/.local/share/lumina/plugins).
    final source = EditorHostFixture.create(projectName: 'PluginSource');
    addTearDown(source.dispose);
    UserPluginDir.override = Directory(p.join(source.projectDir.path, 'plugins'));
    final a = EditorHostFixture.create(projectName: 'GameA');
    final b = EditorHostFixture.create(projectName: 'GameB');
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    for (final f in [a, b]) {
      Directory(p.join(f.projectDir.path, 'plugins')).deleteSync(recursive: true);
    }

    // GameA is built (what EditorBuildService leaves behind).
    final plugins = await resolver.enabledCodePlugins(a.projectDir.path);
    expect(plugins.single.pluginDir.path, startsWith(source.projectDir.path));
    await resolver.generator.generate(a.projectDir.path, plugins);
    await a.pubGetHost();
    final components = await fingerprintComponents(await resolver.inputsFor(a.projectDir.path, plugins));
    final hash = fingerprintOf(components);
    final bundle = Directory(p.join(fx.temp.path, 'bundle_a'))..createSync();
    File(p.join(bundle.path, 'game_a_editor.exe')).writeAsStringSync('built');
    await cache.install(hash, bundle, stamp: {'executable': 'game_a_editor.exe', 'inputs': components});

    // GameB opens in that same build.
    await resolver.generator.generate(b.projectDir.path, await resolver.enabledCodePlugins(b.projectDir.path));
    await b.pubGetHost();
    final decision = await resolver.resolve(b.projectDir.path);
    expect(decision, isA<ExecCached>());
    expect((decision as ExecCached).entry.hash, hash);
    expect(cache.hashes(), [hash], reason: 'one entry for both projects');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a project editor self-check reports what changed since it was built', () async {
    final plugins = await resolver.enabledCodePlugins(fx.projectDir.path);
    await resolver.generator.generate(fx.projectDir.path, plugins);
    await fx.pubGetHost();
    final components = await fingerprintComponents(await resolver.inputsFor(fx.projectDir.path, plugins));
    final hash = fingerprintOf(components);
    File(p.join(fx.hostDir, EditorHostGeneratorService.stampFileName))
        .writeAsStringSync(jsonEncode({'hash': hash, 'inputs': components}));
    expect(await resolver.staleSelfCheck(fx.projectDir.path, hash), isEmpty);
    expect(await resolver.staleSelfCheck(fx.projectDir.path, ''), isEmpty, reason: 'not a built project editor');

    File(p.join(fx.pluginDir.path, 'lib', 'b.dart')).writeAsStringSync('// new file\n');
    expect(await resolver.staleSelfCheck(fx.projectDir.path, hash), ['plugin a_plugin changed']);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

