import 'dart:io';

import 'package:lumina/data/services/editor_build_fingerprint.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'editor_build_test_support.dart';

/// What decides whether a project editor is stale.
void main() {
  late EditorBuildFixture fx;
  late Directory engine, host;

  setUp(() async {
    fx = await EditorBuildFixture.create();
    // A temp engine root: not a git checkout, so the repos are hashed by
    // their source manifest.
    engine = Directory(p.join(fx.temp.path, 'engine'))..createSync();
    for (final repo in ['lumina_ui', 'lumina', 'lumina_editor_api', 'flutter_filament']) {
      Directory(p.join(engine.path, repo, 'lib')).createSync(recursive: true);
      File(p.join(engine.path, repo, 'lib', '$repo.dart')).writeAsStringSync('// $repo\n');
      File(p.join(engine.path, repo, 'pubspec.yaml')).writeAsStringSync('name: $repo\n');
    }
    Directory(p.join(engine.path, 'flutter_filament', 'src')).createSync();
    File(p.join(engine.path, 'flutter_filament', 'src', 'engine_c.cpp')).writeAsStringSync('int a;\n');
    host = Directory(p.join(fx.projectDir.path, '.lumina', 'editor'))..createSync(recursive: true);
    File(p.join(host.path, 'pubspec.yaml')).writeAsStringSync('name: host_game_editor\n');
    File(p.join(host.path, 'pubspec.lock')).writeAsStringSync('packages: {}\n');
  });
  tearDown(() => fx.dispose());

  EditorHostInputs inputs({String mode = 'release', String flutterVersion = '3.41.0', String flutterRevision = 'aaaa'}) => EditorHostInputs(
        hostDir: host.path,
        engineRoot: engine.path,
        pluginDirs: {'a_plugin': fx.pluginDir.path},
        flutterVersion: flutterVersion,
        flutterRevision: flutterRevision,
        platform: 'linux-x64',
        mode: mode,
      );

  test('the same inputs give the same hash', () async {
    final a = await fingerprint(inputs());
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(await fingerprint(inputs()), a);
  });

  test('one byte in a plugin source (pubspec unchanged) changes it, and diffInputs names the plugin', () async {
    final before = await fingerprintComponents(inputs());
    final pubspec = File(p.join(fx.pluginDir.path, 'pubspec.yaml')).readAsBytesSync();
    final a = File(p.join(fx.pluginDir.path, 'lib', 'a.dart'));
    a.writeAsStringSync('${a.readAsStringSync()} ');
    final after = await fingerprintComponents(inputs());
    expect(File(p.join(fx.pluginDir.path, 'pubspec.yaml')).readAsBytesSync(), pubspec);
    expect(fingerprintOf(after), isNot(fingerprintOf(before)));
    expect(diffInputs(before, after), ['plugin a_plugin changed']);
  });

  test("the .lmplugin's isolation and process_class change it (they change the registrar), and diffInputs names the plugin",
      () async {
    final before = await fingerprintComponents(inputs());
    await fx.isolate();
    final after = await fingerprintComponents(inputs());
    expect(diffInputs(before, after), ['plugin a_plugin changed']);

    // The manifest alone (sources unchanged): back to in process.
    final manifest = File(p.join(fx.pluginDir.path, 'a_plugin.lmplugin'));
    manifest.writeAsStringSync(manifest.readAsStringSync().replaceAll('"isolation":"process"', '"isolation":"in_process"'));
    final reverted = await fingerprintComponents(inputs());
    expect(reverted['plugin:a_plugin'], isNot(after['plugin:a_plugin']));
    expect(fingerprintOf(reverted), isNot(fingerprintOf(after)));
  });

  test('a new file in lumina_ui/lib of the engine changes it, and diffInputs names the engine repo', () async {
    final before = await fingerprintComponents(inputs());
    File(p.join(engine.path, 'lumina_ui', 'lib', 'new_panel.dart')).writeAsStringSync('// new\n');
    final after = await fingerprintComponents(inputs());
    expect(fingerprintOf(after), isNot(fingerprintOf(before)));
    expect(diffInputs(before, after), ['editor source changed (lumina_ui)']);
  });

  test("a change in lumina_ui's platform runner changes it; the runner's flutter/ephemeral does not", () async {
    final runner = Directory(p.join(engine.path, 'lumina_ui', 'windows', 'runner'))..createSync(recursive: true);
    final main = File(p.join(runner.path, 'main.cpp'))..writeAsStringSync('int main() { return 0; }\n');
    final ephemeral = Directory(p.join(engine.path, 'lumina_ui', 'windows', 'flutter', 'ephemeral'))..createSync(recursive: true);
    final before = await fingerprintComponents(inputs());

    File(p.join(ephemeral.path, 'generated_config.cmake')).writeAsStringSync('# tool output\n');
    expect(fingerprintOf(await fingerprintComponents(inputs())), fingerprintOf(before));

    main.writeAsStringSync('int main() { return 1; }\n');
    final after = await fingerprintComponents(inputs());
    expect(fingerprintOf(after), isNot(fingerprintOf(before)));
    expect(diffInputs(before, after), ['editor source changed (lumina_ui)']);
  });

  test('debug vs release and a Flutter upgrade each change it, and are named', () async {
    final release = await fingerprintComponents(inputs());
    final debug = await fingerprintComponents(inputs(mode: 'debug'));
    expect(fingerprintOf(debug), isNot(fingerprintOf(release)));
    expect(diffInputs(release, debug), ['build mode release → debug']);

    final upgraded = await fingerprintComponents(inputs(flutterVersion: '3.44.0', flutterRevision: 'bbbb'));
    expect(fingerprintOf(upgraded), isNot(fingerprintOf(release)));
    expect(diffInputs(release, upgraded), ['Flutter 3.41.0 → 3.44.0']);
  });

  test('two projects with the same plugins on the same engine share a fingerprint (one cache entry)', () async {
    final other = Directory(p.join(fx.temp.path, 'OtherGame', '.lumina', 'editor'))..createSync(recursive: true);
    // The generator names each host after its project; the name is not an input.
    File(p.join(other.path, 'pubspec.yaml')).writeAsStringSync('# GENERATED for OtherGame\nname: other_game_editor\n');
    File(p.join(other.path, 'pubspec.lock')).writeAsStringSync('packages: {}\n');
    File(p.join(host.path, 'pubspec.yaml')).writeAsStringSync('# GENERATED for HostGame\nname: host_game_editor\n');
    final a = await fingerprint(inputs());
    final b = await fingerprint(EditorHostInputs(
      hostDir: other.path,
      engineRoot: engine.path,
      pluginDirs: {'a_plugin': fx.pluginDir.path},
      flutterVersion: '3.41.0',
      flutterRevision: 'aaaa',
      platform: 'linux-x64',
      mode: 'release',
    ));
    expect(b, a);
    File(p.join(other.path, 'pubspec.yaml')).writeAsStringSync('name: other_game_editor\ndependencies: {b_plugin: {path: /b}}\n');
    expect(await fingerprint(EditorHostInputs(
      hostDir: other.path,
      engineRoot: engine.path,
      pluginDirs: {'a_plugin': fx.pluginDir.path},
      flutterVersion: '3.41.0',
      flutterRevision: 'aaaa',
      platform: 'linux-x64',
      mode: 'release',
    )), isNot(a), reason: 'a different dependency set is a different editor');
  });

  test('a changed host lock is reported as a package change', () async {
    final before = await fingerprintComponents(inputs());
    File(p.join(host.path, 'pubspec.lock')).writeAsStringSync('packages: {x: 1}\n');
    final after = await fingerprintComponents(inputs());
    expect(diffInputs(before, after), ['editor host packages changed']);
  });

  test('a git engine repo is hashed by HEAD + diff + untracked sources', () async {
    final repo = Directory(p.join(engine.path, 'lumina'));
    Future<ProcessResult> git(List<String> args) => Process.run('git', args, workingDirectory: repo.path);
    try {
      if ((await git(['init', '-q'])).exitCode != 0) throw const ProcessException('git', []);
    } on ProcessException {
      markTestSkipped('git is not available');
      return;
    }
    await git(['-c', 'user.email=t@t', '-c', 'user.name=t', 'add', '.']);
    await git(['-c', 'user.email=t@t', '-c', 'user.name=t', '-c', 'commit.gpgsign=false', 'commit', '-q', '-m', 'init']);
    final clean = await fingerprintComponents(inputs());
    expect(clean['engine:lumina'], startsWith('git:'));

    File(p.join(repo.path, 'lib', 'lumina.dart')).writeAsStringSync('// edited\n');
    final edited = await fingerprintComponents(inputs());
    expect(diffInputs(clean, edited), ['editor source changed (lumina)'], reason: 'a local edit');

    File(p.join(repo.path, 'lib', 'lumina.dart')).writeAsStringSync('// lumina\n');
    expect((await fingerprintComponents(inputs()))['engine:lumina'], clean['engine:lumina']);
    File(p.join(repo.path, 'lib', 'untracked.dart')).writeAsStringSync('// new\n');
    expect(diffInputs(clean, await fingerprintComponents(inputs())), ['editor source changed (lumina)'], reason: 'an untracked file');
  });
}
