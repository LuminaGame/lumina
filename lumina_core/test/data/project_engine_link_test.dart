import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// A generated game project's link to the engine: the git dependency in
/// pubspec.yaml, the local checkout in a gitignored pubspec_overrides.yaml,
/// and the native hooks' settings.
void main() {
  late Directory temp;
  final engineRoot = LuminaWorkspace.root;
  String slash(String s) => p.normalize(s).replaceAll(r'\', '/');

  setUp(() => temp = Directory.systemTemp.createTempSync('project_engine_link_'));
  tearDown(() => temp.deleteSync(recursive: true));

  const flutterCreatePubspec = '''
name: a_game
description: "A new Flutter project."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''';

  group('withGitEngineDependency', () {
    test('adds lumina and lumina_widgets as git dependencies under dependencies:', () {
      final out = ProjectEngineLink.withGitEngineDependency(flutterCreatePubspec);
      expect(
          out,
          contains('dependencies:\n  lumina:\n    git:\n      url: $kLuminaGitUrl\n      path: lumina\n'
              '  lumina_widgets:\n    git:\n      url: $kLuminaGitUrl\n      path: lumina_widgets\n  flutter:\n'));
      final deps = (loadYaml(out) as YamlMap)['dependencies'] as YamlMap;
      expect((deps['lumina'] as YamlMap)['git'], {'url': kLuminaGitUrl, 'path': 'lumina'});
      expect((deps['lumina_widgets'] as YamlMap)['git'], {'url': kLuminaGitUrl, 'path': 'lumina_widgets'});
    });

    test('replaces a path dependency (an old project or template) and is idempotent', () {
      final old = flutterCreatePubspec.replaceFirst(
          'dependencies:\n', 'dependencies:\n  lumina:\n    path: /home/someone/lumina/lumina\n');
      final out = ProjectEngineLink.withGitEngineDependency(old);
      expect(out, isNot(contains('/home/someone')));
      expect(ProjectEngineLink.withGitEngineDependency(out), out);
      expect(RegExp(r'^  lumina:', multiLine: true).allMatches(out).length, 1);
      expect(RegExp(r'^  lumina_widgets:', multiLine: true).allMatches(out).length, 1);
      expect(out, contains('  cupertino_icons: ^1.0.8\n'));
    });

    test('keeps CRLF line endings', () {
      final out = ProjectEngineLink.withGitEngineDependency(flutterCreatePubspec.replaceAll('\n', '\r\n'));
      expect(out.replaceAll('\r\n', ''), isNot(contains('\n')));
      expect(out, contains('  lumina:\r\n    git:\r\n'));
    });
  });

  group('release commit pinning', () {
    const sha = '0123456789abcdef0123456789abcdef01234567';
    tearDown(LuminaWorkspace.clearCheckout);

    test('a source workspace writes no ref:', () {
      expect(LuminaWorkspace.engineCommit, isNull);
      expect(ProjectEngineLink.engineDependency(), isNot(contains('ref:')));
    });

    test('an explicit ref pins the git dependency', () {
      final out = ProjectEngineLink.withGitEngineDependency(flutterCreatePubspec, ref: sha);
      final deps = (loadYaml(out) as YamlMap)['dependencies'] as YamlMap;
      expect(deps['lumina']['git'], {'url': kLuminaGitUrl, 'path': 'lumina', 'ref': sha});
      expect(deps['lumina_widgets']['git'], {'url': kLuminaGitUrl, 'path': 'lumina_widgets', 'ref': sha});
      expect(ProjectEngineLink.withGitEngineDependency(out, ref: sha), out, reason: 'idempotent');
    });

    test('a fetched release checkout pins its commit and repo by default', () {
      LuminaWorkspace.useCheckout(engineRoot, commit: sha, repo: 'file:///D:/remote/lumina.git');
      final out = ProjectEngineLink.withGitEngineDependency(flutterCreatePubspec);
      final git = ((loadYaml(out) as YamlMap)['dependencies'] as YamlMap)['lumina']['git'] as YamlMap;
      expect(git['ref'], sha);
      expect(git['url'], 'file:///D:/remote/lumina.git');
    });

    test('a release editor re-pins an older ref; a source editor keeps it', () {
      final old = ProjectEngineLink.withGitEngineDependency(flutterCreatePubspec, ref: 'aaaaaaa');
      expect(ProjectEngineLink.withGitEngineDependency(old), contains('      ref: aaaaaaa\n'), reason: 'kept without a release');
      LuminaWorkspace.useCheckout(engineRoot, commit: sha);
      final repinned = ProjectEngineLink.withGitEngineDependency(old);
      expect(repinned, contains('      ref: $sha\n'));
      expect(repinned, isNot(contains('aaaaaaa')));
      expect(RegExp(r'^      ref:', multiLine: true).allMatches(repinned).length, 2, reason: 'one per engine package');
    });

    test('an older project with lumina only gets lumina_widgets at the same ref', () {
      final old = flutterCreatePubspec.replaceFirst('dependencies:\n',
          'dependencies:\n  lumina:\n    git:\n      url: $kLuminaGitUrl\n      path: lumina\n      ref: bbbbbbb\n');
      final deps = (loadYaml(ProjectEngineLink.withGitEngineDependency(old)) as YamlMap)['dependencies'] as YamlMap;
      expect(deps['lumina']['git']['ref'], 'bbbbbbb');
      expect(deps['lumina_widgets']['git'], {'url': kLuminaGitUrl, 'path': 'lumina_widgets', 'ref': 'bbbbbbb'});
    });

    test('apply() from a release checkout without overrides writes the ref and the hook settings', () {
      final project = Directory(p.join(temp.path, 'game'))..createSync();
      File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(flutterCreatePubspec);
      LuminaWorkspace.useCheckout(engineRoot, commit: sha);
      final result = ProjectEngineLink.apply(project.path, localOverrides: false);
      final pubspec = File(p.join(project.path, 'pubspec.yaml')).readAsStringSync();
      final yaml = loadYaml(pubspec) as YamlMap;
      expect((yaml['dependencies'] as YamlMap)['lumina']['git']['ref'], sha);
      expect(result.engineRoot, p.normalize(engineRoot));
      expect(File(p.join(project.path, 'pubspec_overrides.yaml')).existsSync(), isFalse);
      if (Directory(p.join(engineRoot, 'filament')).existsSync()) {
        expect(yaml['hooks']['user_defines']['flutter_filament']['filament_dir'], startsWith('file:'));
      }
    });
  });

  group('withHookUserDefines', () {
    const defines = {
      'flutter_filament': {'filament_dir': 'D:/e/filament'},
      'flutter_assimp': {'filament_dir': 'D:/e/filament', 'libcxx_dir': 'D:/e/libcxx'},
    };

    test('appends a hooks block, replaces it on relink and removes it when empty', () {
      final once = ProjectEngineLink.withHookUserDefines(flutterCreatePubspec, defines);
      expect(once, contains("hooks:\n  user_defines:\n    flutter_filament:\n      filament_dir: 'D:/e/filament'\n"
          "    flutter_assimp:\n      filament_dir: 'D:/e/filament'\n      libcxx_dir: 'D:/e/libcxx'\n"));
      expect(ProjectEngineLink.withHookUserDefines(once, defines), once, reason: 'idempotent');
      final moved = ProjectEngineLink.withHookUserDefines(once, {
        'flutter_filament': {'filament_dir': '/opt/filament'},
      });
      expect(moved, isNot(contains('D:/e')));
      expect(RegExp(r'^hooks:', multiLine: true).allMatches(moved).length, 1);
      expect(RegExp(RegExp.escape(ProjectEngineLink.hooksMarker)).allMatches(moved).length, 1);
      expect(ProjectEngineLink.withHookUserDefines(moved, const {}), flutterCreatePubspec);
      final yaml = loadYaml(once) as YamlMap;
      expect((yaml['flutter'] as YamlMap)['uses-material-design'], isTrue, reason: 'the flutter: section is intact');
    });

    test("a user's own hooks block is kept and no second one is added", () {
      final own = '${flutterCreatePubspec}hooks:\n  user_defines:\n    my_pkg:\n      flag: true\n';
      expect(ProjectEngineLink.withHookUserDefines(own, defines), own);
      expect(ProjectEngineLink.withHookUserDefines(own, const {}), own);
      expect(ProjectEngineLink.withHookUserDefines(own, const {}, anyBlock: true), flutterCreatePubspec,
          reason: "a template's block is dropped");
    });
  });

  test('hookUserDefines resolves the engine workspace settings to existing absolute dirs', () {
    if (!File(p.join(engineRoot, 'lumina', 'pubspec.yaml')).existsSync()) return markTestSkipped('no engine checkout');
    final defines = ProjectEngineLink.hookUserDefines(engineRoot);
    // file: URIs: the hooks resolve a value against the pubspec's URI, and
    // `D:/…` would read as the scheme `d`.
    final filament = Uri.directory(p.normalize(p.join(engineRoot, 'filament'))).toString();
    expect(defines['flutter_filament']?['filament_dir'], filament);
    expect(defines['flutter_assimp']?['filament_dir'], filament);
    final pubspecUri = Uri.file(p.join(temp.path, 'pubspec.yaml'));
    for (final package in defines.values) {
      for (final value in package.values) {
        expect(value, startsWith('file:///'), reason: value);
        final dir = pubspecUri.resolve(value).toFilePath();
        expect(Directory(dir).existsSync(), isTrue, reason: dir);
      }
    }
  });

  test('apply without local overrides (building against git) writes the hook settings, unless an overrides file is in effect', () {
    if (!File(p.join(engineRoot, 'lumina', 'pubspec.yaml')).existsSync()) return markTestSkipped('no engine checkout');
    final project = Directory(p.join(temp.path, 'git_game'))..createSync();
    final pubspecFile = File(p.join(project.path, 'pubspec.yaml'))..writeAsStringSync(flutterCreatePubspec);
    final result =
        ProjectEngineLink.apply(project.path, luminaPackageDir: p.join(engineRoot, 'lumina'), localOverrides: false);
    expect(result.overrides, isEmpty);
    expect(result.hookUserDefines['flutter_assimp']?['filament_dir'], startsWith('file:///'));
    final withHooks = pubspecFile.readAsStringSync();
    expect(withHooks, contains('url: $kLuminaGitUrl'));
    expect(withHooks, contains('${ProjectEngineLink.hooksMarker}\n'));
    expect(withHooks, contains('hooks:\n  user_defines:\n    flutter_filament:\n'));
    expect(File(p.join(project.path, 'pubspec_overrides.yaml')).existsSync(), isFalse);
    ProjectEngineLink.apply(project.path, luminaPackageDir: p.join(engineRoot, 'lumina'), localOverrides: false);
    expect(pubspecFile.readAsStringSync(), withHooks, reason: 'idempotent');

    // Relinking with local overrides removes the block it wrote.
    ProjectEngineLink.apply(project.path, luminaPackageDir: p.join(engineRoot, 'lumina'));
    final relinked = pubspecFile.readAsStringSync();
    expect(relinked, isNot(contains('hooks:')));
    expect(relinked, isNot(contains(ProjectEngineLink.hooksMarker)));
    expect(File(p.join(project.path, 'pubspec_overrides.yaml')).existsSync(), isTrue);

    // An overrides file in effect: still no hook block when building "against git".
    ProjectEngineLink.apply(project.path, luminaPackageDir: p.join(engineRoot, 'lumina'), localOverrides: false);
    expect(pubspecFile.readAsStringSync(), relinked);
  });

  test('apply links a project to the local engine: git dependency and gitignored overrides, no hook settings', () {
    if (!File(p.join(engineRoot, 'lumina', 'pubspec.yaml')).existsSync()) return markTestSkipped('no engine checkout');
    final project = Directory(p.join(temp.path, 'a_game'))..createSync();
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(flutterCreatePubspec);
    File(p.join(project.path, '.gitignore')).writeAsStringSync('build/\n');

    final result = ProjectEngineLink.apply(project.path, luminaPackageDir: p.join(engineRoot, 'lumina'));
    expect(result.isLocal, isTrue);
    expect(result.engineRoot, p.normalize(engineRoot));
    expect(result.hookUserDefines, isEmpty);

    final pubspec = File(p.join(project.path, 'pubspec.yaml')).readAsStringSync();
    expect(pubspec, contains('url: $kLuminaGitUrl'));
    expect(pubspec, isNot(contains('hooks:')), reason: "each local package's hook finds its own ../filament");

    final overrides = File(p.join(project.path, 'pubspec_overrides.yaml')).readAsStringSync();
    final pinned = ((loadYaml(overrides) as YamlMap)['dependency_overrides'] as YamlMap);
    // The engine, the game's Flutter side and their closure; the editor's
    // importers (Assimp, RigLogic) are not a game's.
    for (final name in ['lumina', 'lumina_widgets', 'lumina_core', 'flutter_filament', 'flutter_gstreamer', 'lumina_smoke', 'lumina_mouse_capture']) {
      expect(pinned.keys, contains(name));
      final dir = (pinned[name] as YamlMap)['path'] as String;
      expect(File(p.join(dir, 'pubspec.yaml')).existsSync(), isTrue, reason: '$name at $dir');
    }
    expect(pinned.keys, isNot(contains('flutter_assimp')));
    expect(slash((pinned['lumina'] as YamlMap)['path'] as String), slash(p.join(engineRoot, 'lumina')));
    expect(slash((pinned['lumina_widgets'] as YamlMap)['path'] as String), slash(p.join(engineRoot, 'lumina_widgets')));
    expect(File(p.join(project.path, '.gitignore')).readAsLinesSync(), contains('pubspec_overrides.yaml'));

    // A second link changes nothing.
    final before = {
      for (final f in ['pubspec.yaml', 'pubspec_overrides.yaml', '.gitignore'])
        f: File(p.join(project.path, f)).readAsStringSync(),
    };
    ProjectEngineLink.apply(project.path, luminaPackageDir: p.join(engineRoot, 'lumina'));
    for (final e in before.entries) {
      expect(File(p.join(project.path, e.key)).readAsStringSync(), e.value, reason: e.key);
    }
  });

  group('an engine whose tools packages come from the pub cache (a release checkout)', () {
    late String engine;
    late String project;
    late Map<String, String> packages;
    final lib = Platform.isWindows ? 'riglogic.lib' : 'libriglogic.a';

    void write(String path, String text) => File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    setUp(() {
      engine = p.join(temp.path, 'engine');
      project = p.join(temp.path, 'Game');
      write(p.join(engine, 'pubspec.yaml'), '''
name: engine_workspace
hooks:
  user_defines:
    flutter_filament:
      filament_dir: filament
    flutter_assimp:
      filament_dir: filament
    flutter_riglogic:
      riglogic_lib_dir: openriglogic/lib
''');
      write(p.join(engine, 'filament', 'include', 'x.h'), '// filament');
      write(p.join(engine, 'openriglogic', 'lib', lib), 'library');
      write(p.join(engine, 'flutter_filament', 'pubspec.yaml'), 'name: flutter_filament');
      final cache = p.join(temp.path, 'pub-cache', 'git', 'tools-0123');
      write(p.join(cache, 'flutter_assimp', 'pubspec.yaml'), 'name: flutter_assimp');
      write(p.join(cache, 'flutter_riglogic', 'pubspec.yaml'), 'name: flutter_riglogic');
      write(p.join(project, 'pubspec.yaml'), flutterCreatePubspec);
      packages = {
        'flutter_filament': p.join(engine, 'flutter_filament'),
        'flutter_assimp': p.join(cache, 'flutter_assimp'),
        'flutter_riglogic': p.join(cache, 'flutter_riglogic'),
      };
    });

    test('needs hook settings only when a hooked package has no Filament beside it', () {
      expect(ProjectEngineLink.needsHookUserDefines(packages), isTrue);
      expect(ProjectEngineLink.needsHookUserDefines({'flutter_filament': packages['flutter_filament']!}), isFalse);
    });

    test('the settings name gitignored links in .lumina/engine: no machine path in the pubspec', () {
      final defines = ProjectEngineLink.linkedHookUserDefines(project, engine, packages: packages);
      expect(defines['flutter_filament'], {'filament_dir': '.lumina/engine/filament'});
      expect(defines['flutter_assimp'], {'filament_dir': '.lumina/engine/filament'});
      expect(defines['flutter_riglogic'], {'riglogic_lib_dir': '.lumina/engine/riglogic_lib'});
      expect(File(p.join(project, '.lumina', 'engine', 'filament', 'include', 'x.h')).readAsStringSync(), '// filament');
      expect(File(p.join(project, '.lumina', 'engine', 'riglogic_lib', lib)).readAsStringSync(), 'library');
      if (Platform.isWindows) {
        // Junctions (IO_REPARSE_TAG_MOUNT_POINT), not symbolic links: no admin rights or Developer Mode needed.
        final q = Process.runSync('fsutil', ['reparsepoint', 'query', p.join(project, '.lumina', 'engine', 'filament')]);
        expect('${q.stdout}'.toLowerCase(), contains('0xa0000003'));
      }

      final pubspec = ProjectEngineLink.withHookUserDefines(flutterCreatePubspec, defines);
      expect(pubspec, contains("    flutter_riglogic:\n      riglogic_lib_dir: '.lumina/engine/riglogic_lib'\n"));
      expect(pubspec, isNot(contains(slash(temp.path))));
      expect(pubspec, isNot(contains(':/')), reason: 'no drive or file: URI');
    });

    test('a relink drops links no setting names any more', () {
      ProjectEngineLink.linkedHookUserDefines(project, engine, packages: packages);
      Directory(p.join(engine, 'openriglogic')).deleteSync(recursive: true);
      final defines = ProjectEngineLink.linkedHookUserDefines(project, engine, packages: packages);
      expect(defines['flutter_riglogic'], isNull);
      expect(FileSystemEntity.typeSync(p.join(project, '.lumina', 'engine', 'riglogic_lib'), followLinks: false),
          FileSystemEntityType.notFound);
      expect(FileSystemEntity.isLinkSync(p.join(project, '.lumina', 'engine', 'filament')), isTrue);
    });
  });

  test('without a local engine only the git dependency is written', () {
    final project = Directory(p.join(temp.path, 'b_game'))..createSync();
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(flutterCreatePubspec);
    final result = ProjectEngineLink.apply(project.path, luminaPackageDir: p.join(temp.path, 'no_engine', 'lumina'));
    expect(result.isLocal, isFalse);
    final pubspec = File(p.join(project.path, 'pubspec.yaml')).readAsStringSync();
    expect(pubspec, contains('url: $kLuminaGitUrl'));
    expect(pubspec, isNot(contains('hooks:')));
    expect(File(p.join(project.path, 'pubspec_overrides.yaml')).existsSync(), isFalse);
  });
}
