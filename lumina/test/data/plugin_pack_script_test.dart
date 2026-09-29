import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/plugin_pack_script.dart';
import 'package:lumina/data/services/workspace_paths.dart';

/// The `tool/pack_plugin.dart` every Lumina plugin carries (the plugin
/// template generator emits [kPluginPackScript]): run for real with `dart` on
/// real plugin folders in `Directory.systemTemp`, its zip read back with
/// package:archive (CRCs verified).
void main() {
  late Directory tempRoot;

  setUp(() => tempRoot = Directory.systemTemp.createTempSync('plugin_pack_script_test_'));
  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  File write(Directory dir, String rel, Object contents) {
    final f = File('${dir.path}/$rel')..parent.createSync(recursive: true);
    if (contents is String) {
      f.writeAsStringSync(contents);
    } else {
      f.writeAsBytesSync(contents as List<int>);
    }
    return f;
  }

  Map<String, Object?> manifest(String name, {String version = '0.2.0', Map<String, Object?> extra = const {}}) => {
        'name': name,
        'friendly_name': 'My Plugin',
        'version': version,
        'description': 'A test plugin.',
        'category': 'Other',
        'license': 'MIT',
        'changelog': 'CHANGELOG.md',
        'authors': ['Lumina'],
        'engine_version': '>=0.0.1 <1.0.0',
        'can_contain_content': false,
        'modules': <Object?>[],
        ...extra,
      };

  /// A plugin folder as it sits on a developer's disk: sources plus the build
  /// outputs, tool folders and downloads a pack must leave out.
  Directory pluginFixture({String name = 'my_plugin', String version = '0.2.0', bool withPubspec = true}) {
    final dir = Directory('${tempRoot.path}/$name')..createSync(recursive: true);
    write(dir, '$name.lmplugin', const JsonEncoder.withIndent('  ').convert(manifest(name, version: version)));
    if (withPubspec) {
      write(dir, 'pubspec.yaml', 'name: $name\nversion: $version\npublish_to: none\n\nenvironment:\n  sdk: ^3.9.0\n');
    }
    write(dir, 'lib/$name.dart', 'library;\n\nconst answer = 42;\n');
    write(dir, 'lib/src/impl.dart', 'const impl = 1;\n');
    write(dir, 'README.md', '# My Plugin\n');
    write(dir, 'CHANGELOG.md', '## $version\n\n- First.\n');
    write(dir, 'LICENSE', 'MIT License\n\nCopyright (c) 2026 Lumina\n');
    write(dir, 'resources/icon128.png', [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
    write(dir, 'test/${name}_test.dart', 'void main() {}\n');
    write(dir, 'analysis_options.yaml', 'include: package:flutter_lints/flutter.yaml\n');
    write(dir, '.gitignore', '# generated\n/pubspec.lock\n*.txt\n!notes.txt\nsecrets/\n');
    write(dir, 'lib/.gitignore', 'generated/\n');
    write(dir, 'tool/$kPluginPackScriptFileName', kPluginPackScript);

    // Everything below must stay out of the pack.
    write(dir, 'build/pack/old-0.0.1.zip', [1, 2, 3]);
    write(dir, 'build/lib/big.bin', List.filled(1000, 7));
    write(dir, '.dart_tool/flutter_build/cache.dill', [1, 2, 3]);
    write(dir, '.git/HEAD', 'ref: refs/heads/main\n');
    write(dir, '.idea/workspace.xml', '<x/>');
    write(dir, '.vscode/settings.json', '{}');
    write(dir, 'node_modules/left/index.js', 'x');
    write(dir, 'lib/.dart_tool/x.json', '{}');
    write(dir, 'pubspec.lock', '# lock\n');
    write(dir, 'pubspec_overrides.yaml', 'dependency_overrides: {}\n');
    write(dir, 'resources/model.glb.part', [1, 2]);
    write(dir, 'debug.log', 'log');
    write(dir, 'scratch.txt', 'ignored by *.txt');
    write(dir, 'notes.txt', 're-included by !notes.txt');
    write(dir, 'secrets/key.json', '{}');
    write(dir, 'lib/generated/gen.dart', 'const gen = 0;\n');
    write(dir, '.DS_Store', 'x');
    write(dir, '.env.local', 'API_KEY=secret');
    write(dir, 'resources/credentials.json', '{"key": "secret"}');
    return dir;
  }

  /// Runs the script on [dir] (named as the argument, so `dart` resolves no
  /// fixture pubspec: a broken one must reach the script's own checks).
  Future<ProcessResult> pack(Directory dir, [List<String> args = const []]) {
    final script = File('${tempRoot.path}/runner/$kPluginPackScriptFileName');
    if (!script.existsSync()) write(tempRoot, 'runner/$kPluginPackScriptFileName', kPluginPackScript);
    return Process.run(
      'dart',
      ['run', script.path, dir.path, ...args],
      workingDirectory: tempRoot.path,
      runInShell: Platform.isWindows,
    );
  }

  Map<String, List<int>> unzip(File zip) {
    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync(), verify: true);
    return {for (final e in archive) if (e.isFile) e.name: e.readBytes()!};
  }

  test('packs the plugin folder under <name>/ into build/pack/<name>-<version>.zip, leaving out build outputs and '
      'ignored files', () async {
    final dir = pluginFixture();
    final res = await pack(dir);
    expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');

    final zip = File('${dir.path}/build/pack/my_plugin-0.2.0.zip');
    expect(zip.existsSync(), isTrue);
    expect(res.stdout as String, contains(['build', 'pack', 'my_plugin-0.2.0.zip'].join(Platform.pathSeparator)));
    expect(res.stdout as String, contains('14 files'));

    final files = unzip(zip);
    expect(files.keys.toSet(), {
      'my_plugin/.gitignore',
      'my_plugin/CHANGELOG.md',
      'my_plugin/LICENSE',
      'my_plugin/README.md',
      'my_plugin/analysis_options.yaml',
      'my_plugin/lib/.gitignore',
      'my_plugin/lib/my_plugin.dart',
      'my_plugin/lib/src/impl.dart',
      'my_plugin/my_plugin.lmplugin',
      'my_plugin/notes.txt',
      'my_plugin/pubspec.yaml',
      'my_plugin/resources/icon128.png',
      'my_plugin/test/my_plugin_test.dart',
      'my_plugin/tool/pack_plugin.dart',
    });
    expect(files['my_plugin/lib/src/impl.dart'], File('${dir.path}/lib/src/impl.dart').readAsBytesSync());
    expect(files['my_plugin/resources/icon128.png'], File('${dir.path}/resources/icon128.png').readAsBytesSync());
    expect(files['my_plugin/tool/pack_plugin.dart'], utf8.encode(kPluginPackScript));
    // No leftover temp file next to the archive.
    expect(Directory('${dir.path}/build/pack').listSync().map((e) => e.uri.pathSegments.last).toSet(),
        {'old-0.0.1.zip', 'my_plugin-0.2.0.zip'});
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('--out writes the archive to the given folder; a repack is identical', () async {
    final dir = pluginFixture();
    final out = Directory('${tempRoot.path}/dist');
    final first = await pack(dir, ['--out', out.path]);
    expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
    final zip = File('${out.path}/my_plugin-0.2.0.zip');
    final bytes = zip.readAsBytesSync();
    expect(File('${dir.path}/build/pack/my_plugin-0.2.0.zip').existsSync(), isFalse);

    final second = await pack(dir, ['--out', out.path]);
    expect(second.exitCode, 0, reason: '${second.stdout}\n${second.stderr}');
    expect(zip.readAsBytesSync(), bytes, reason: 'the same sources pack to the same bytes');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a .pubignore replaces the .gitignore of its folder (pub semantics)', () async {
    final dir = pluginFixture();
    write(dir, '.pubignore', 'test/\n*.txt\n');
    final res = await pack(dir);
    expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
    final names = unzip(File('${dir.path}/build/pack/my_plugin-0.2.0.zip')).keys.toSet();
    expect(names, isNot(contains('my_plugin/test/my_plugin_test.dart')));
    expect(names, isNot(contains('my_plugin/notes.txt')));
    // The .gitignore no longer applies at the root; the built-in exclusions still do.
    expect(names, contains('my_plugin/pubspec.lock'));
    expect(names, contains('my_plugin/secrets/key.json'));
    expect(names, isNot(contains('my_plugin/pubspec_overrides.yaml')));
    expect(names.where((n) => n.contains('/build/') || n.contains('.dart_tool') || n.endsWith('.part')), isEmpty);
    // A folder's own .gitignore still applies below it.
    expect(names, isNot(contains('my_plugin/lib/generated/gen.dart')));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('refuses files the marketplace does not accept, naming every one, and writes nothing', () async {
    final dir = pluginFixture();
    write(dir, 'bin/helper.exe', [0x4D, 0x5A]);
    write(dir, 'resources/Makefile', 'all:\n');
    final res = await pack(dir);
    expect(res.exitCode, isNot(0));
    expect(res.stderr as String, contains('bin/helper.exe'));
    expect(res.stderr as String, contains('resources/Makefile'));
    expect(File('${dir.path}/build/pack/my_plugin-0.2.0.zip').existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('refuses a manifest the marketplace would refuse', () async {
    final badVersion = pluginFixture(name: 'bad_version', version: '1.0');
    var res = await pack(badVersion);
    expect(res.exitCode, isNot(0));
    expect(res.stderr as String, contains('"1.0"'));

    final mismatch = pluginFixture(name: 'mismatch');
    write(mismatch, 'mismatch.lmplugin', jsonEncode(manifest('other_name')));
    res = await pack(mismatch);
    expect(res.exitCode, isNot(0));
    expect(res.stderr as String, contains('other_name'));

    final missingChangelog = pluginFixture(name: 'no_changelog');
    File('${missingChangelog.path}/CHANGELOG.md').deleteSync();
    res = await pack(missingChangelog);
    expect(res.exitCode, isNot(0));
    expect(res.stderr as String, contains('CHANGELOG.md'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('packs a content-only plugin (no pubspec.yaml)', () async {
    final dir = pluginFixture(name: 'dungeon_props', withPubspec: false);
    File('${dir.path}/lib/dungeon_props.dart').deleteSync();
    File('${dir.path}/lib/src/impl.dart').deleteSync();
    write(dir, 'content/meshes/crate.glb', [0x67, 0x6C, 0x54, 0x46]);
    final res = await pack(dir);
    expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
    final names = unzip(File('${dir.path}/build/pack/dungeon_props-0.2.0.zip')).keys.toSet();
    expect(names, containsAll(['dungeon_props/dungeon_props.lmplugin', 'dungeon_props/content/meshes/crate.glb']));
    expect(names, isNot(contains('dungeon_props/pubspec.yaml')));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('the workspace plugins carry the current script', () {
    // The plugins repo's checkouts, where the workspace resolved them.
    for (final plugin in ['lumina_plugin_pcg', 'lumina_plugin_miniai']) {
      final dir = LuminaWorkspace.package(plugin);
      final script = File('$dir/tool/$kPluginPackScriptFileName');
      if (!Directory(dir).existsSync()) continue;
      expect(script.existsSync(), isTrue, reason: '$plugin has no tool/$kPluginPackScriptFileName');
      expect(script.readAsStringSync().replaceAll('\r\n', '\n'), kPluginPackScript.replaceAll('\r\n', '\n'),
          reason: '$plugin/tool/$kPluginPackScriptFileName differs from kPluginPackScript; copy it over');
    }
  });
}
