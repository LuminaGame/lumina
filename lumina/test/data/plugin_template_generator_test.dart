import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/services/plugin_template_generator_service.dart';

void main() {
  late Directory tempRoot;
  late Directory projectRoot;
  late Directory editorApiRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('plugin_generator_test_');
    projectRoot = Directory('${tempRoot.path}/my_project')..createSync(recursive: true);
    editorApiRoot = Directory('${tempRoot.path}/lumina_editor_api')..createSync(recursive: true);

    File('${projectRoot.path}/project.lmproject')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'project_name': 'my_project', 'version': '0.0.1'}));

    File('${editorApiRoot.path}/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('name: lumina_editor_api\n');
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('PluginTemplateGeneratorService', () {
    test('Blank template into real temp project creates valid package structure and manifest', () async {
      final spawnedCommands = <List<String>>[];

      Future<ProcessResult> recordingRunner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
        spawnedCommands.add([exec, ...args]);
        // Simulate scaffold directory creation
        if (args.contains('create')) {
          final targetDir = Directory(args.last);
          targetDir.createSync(recursive: true);
        }
        return ProcessResult(0, 0, 'ok', '');
      }

      final service = PluginTemplateGeneratorService(
        projectRoot: projectRoot,
        editorApiRoot: editorApiRoot,
        runner: recordingRunner,
      );

      final spec = PluginTemplateSpec(
        templateType: PluginTemplateType.blank,
        name: 'hello_tools',
        friendlyName: 'Hello Tools',
        author: 'Lumina Dev',
        description: 'A friendly greeting tool',
        category: 'Utilities',
      );

      final result = await service.generate(spec);

      expect(result.success, isTrue);
      expect(result.pluginDir, isNotNull);
      expect(result.pluginDir!.existsSync(), isTrue);

      final pluginDir = result.pluginDir!;
      final manifestFile = File('${pluginDir.path}/hello_tools.lmplugin');
      expect(manifestFile.existsSync(), isTrue);

      final pubspecFile = File('${pluginDir.path}/pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);
      final pubspecContent = pubspecFile.readAsStringSync();
      expect(pubspecContent, contains('lumina_editor_api:'));
      // The engine comes from git; the local checkout through the gitignored
      // pubspec_overrides.yaml.
      expect(pubspecContent, contains('  lumina_editor_api:\n    git:\n      url: $kLuminaGitUrl\n      path: lumina_editor_api\n'));
      final overrides = File('${pluginDir.path}/pubspec_overrides.yaml').readAsStringSync();
      expect(overrides, contains("  lumina_editor_api:\n    path: '../../../lumina_editor_api'\n"));
      expect(File('${pluginDir.path}/.gitignore').readAsStringSync(), contains('pubspec_overrides.yaml'));

      final entryFile = File('${pluginDir.path}/lib/hello_tools.dart');
      expect(entryFile.existsSync(), isTrue);
      expect(entryFile.readAsStringSync(), contains("export 'src/hello_tools_plugin.dart';"));

      final pluginSourceFile = File('${pluginDir.path}/lib/src/hello_tools_plugin.dart');
      expect(pluginSourceFile.existsSync(), isTrue);
      final source = pluginSourceFile.readAsStringSync();
      expect(source, contains('class HelloToolsPlugin extends LuminaEditorPlugin'));
      expect(source, contains("registerMenuItem"));
      // Generated plugins register in the Plugins menu.
      expect(source, contains("'Plugins/Hello Tools/About Hello Tools'"));
      expect(source, isNot(contains("'Tools/")));
      final generatedTest = File('${pluginDir.path}/test/hello_tools_plugin_test.dart');
      if (generatedTest.existsSync()) {
        expect(generatedTest.readAsStringSync(), contains('void registerMenu(EditorMenuDescriptor menu)'),
            reason: 'the generated test context implements the full LuminaEditorContext');
      }

      final iconFile = File('${pluginDir.path}/resources/icon128.png');
      expect(iconFile.existsSync(), isTrue);
      expect(iconFile.lengthSync(), greaterThan(0));

      final readmeFile = File('${pluginDir.path}/README.md');
      expect(readmeFile.existsSync(), isTrue);
      expect(readmeFile.readAsStringSync(), contains('Publish: `dart run $kPluginPackScriptPath`, then upload `build/pack/*.zip`.'));
      expect(File('${pluginDir.path}/CHANGELOG.md').readAsStringSync(), startsWith('## 0.1.0'));

      // Every plugin can pack itself for the marketplace.
      final packScript = File('${pluginDir.path}/$kPluginPackScriptPath');
      expect(packScript.existsSync(), isTrue);
      expect(packScript.readAsStringSync(), kPluginPackScript);

      final testFile = File('${pluginDir.path}/test/hello_tools_plugin_test.dart');
      expect(testFile.existsSync(), isTrue);

      final repo = PluginRepository(roots: [
        PluginScanRoot(dir: Directory('${projectRoot.path}/plugins'), origin: PluginOrigin.project),
      ]);
      final desc = await repo.load(manifestFile);
      expect(desc.name, equals('hello_tools'));
      expect(desc.friendlyName, equals('Hello Tools'));
      expect(desc.modules.length, equals(1));
      expect(desc.modules.first.registrationClass, equals('HelloToolsPlugin'));
      expect(desc.modules.first.type, equals(PluginModuleType.editor));
      expect(desc.canContainContent, isFalse);
    });

    test('an isolated plugin: process part, UI shell, both tests, and a manifest naming the process class', () async {
      final service = PluginTemplateGeneratorService(
        projectRoot: projectRoot,
        editorApiRoot: editorApiRoot,
        runner: (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
          if (args.contains('create')) Directory(args.last).createSync(recursive: true);
          return ProcessResult(0, 0, 'ok', '');
        },
      );
      final result = await service.generate(const PluginTemplateSpec(
        templateType: PluginTemplateType.editorPanel,
        name: 'safe_tools',
        friendlyName: r"Safe's $Tools",
        description: 'Runs its work in its own process',
        isolated: true,
      ));
      expect(result.success, isTrue, reason: result.failureOutput);
      final dir = result.pluginDir!.path;

      final manifest = jsonDecode(File('$dir/safe_tools.lmplugin').readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['isolation'], 'process');
      final module = (manifest['modules'] as List).single as Map<String, dynamic>;
      expect(module['registration_class'], 'SafeToolsPlugin');
      expect(module['process_class'], 'SafeToolsProcess');
      expect(result.descriptor!.isolation, PluginIsolation.process);
      expect(result.descriptor!.processClass, 'SafeToolsProcess');

      expect(File('$dir/lib/safe_tools.dart').readAsStringSync(),
          allOf(contains("export 'src/safe_tools_plugin.dart';"), contains("export 'src/safe_tools_process.dart';")));

      final process = File('$dir/lib/src/safe_tools_process.dart').readAsStringSync();
      expect(process, contains('class SafeToolsProcess extends LuminaPluginProcess'));
      expect(process, contains("String get pluginName => 'safe_tools';"));
      expect(process, contains('context.registerMenuItem('));
      expect(process, contains("'Plugins/Safe\\'s \\\$Tools/Say Hello from Safe\\'s \\\$Tools'"),
          reason: 'the friendly name is escaped inside Dart string literals');
      expect(process, contains("context.handle('ping', (args) {"));
      expect(process, contains('context.registerViewPanel('));
      expect(process, isNot(contains('registerImporter')), reason: 'only the importer template imports');

      final shell = File('$dir/lib/src/safe_tools_plugin.dart').readAsStringSync();
      expect(shell, contains('class SafeToolsPlugin extends LuminaEditorPlugin'));
      expect(shell, contains('context.processChannel(pluginName)'));
      expect(shell, contains("widget.channel.call('ping', {'from': 'panel'})"));
      expect(shell, isNot(contains('dart:ffi')));
      expect(shell, isNot(contains('Process.')));

      expect(File('$dir/test/safe_tools_plugin_test.dart').readAsStringSync(), contains('SafeToolsPanel(channel: PluginProcessChannel.detached'));
      expect(File('$dir/test/safe_tools_process_test.dart').readAsStringSync(),
          allOf(contains('LoopbackHost.start()'), contains('runPluginProcessMain('), contains("host.channel.call('ping'")));
      expect(File('$dir/README.md').readAsStringSync(), contains('## Two halves'));
    });

    test('an isolated importer runs its importer in the process part', () async {
      final service = PluginTemplateGeneratorService(
        projectRoot: projectRoot,
        editorApiRoot: editorApiRoot,
        runner: (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
          if (args.contains('create')) Directory(args.last).createSync(recursive: true);
          return ProcessResult(0, 0, 'ok', '');
        },
      );
      final result = await service.generate(const PluginTemplateSpec(
        templateType: PluginTemplateType.importer,
        name: 'safe_importer',
        friendlyName: 'Safe Importer',
        isolated: true,
      ));
      expect(result.success, isTrue, reason: result.failureOutput);
      final process = File('${result.pluginDir!.path}/lib/src/safe_importer_process.dart').readAsStringSync();
      expect(process, contains('context.registerImporter('));
      expect(process, contains("import 'package:lumina/lumina.dart' show LuminaAsset;"));
      expect(File('${result.pluginDir!.path}/lib/src/safe_importer_plugin.dart').readAsStringSync(),
          isNot(contains('registerImporter')));
      expect(File('${result.pluginDir!.path}/pubspec.yaml').readAsStringSync(), contains('  lumina:\n    git:'));
    });

    test('a content-only plugin cannot be isolated', () async {
      final result = await PluginTemplateGeneratorService(projectRoot: projectRoot).generate(const PluginTemplateSpec(
        templateType: PluginTemplateType.contentOnly,
        name: 'just_content',
        friendlyName: 'Just Content',
        isolated: true,
      ));
      expect(result.success, isFalse);
      expect(result.failureOutput, contains('content-only'));
      expect(Directory('${projectRoot.path}/plugins/just_content').existsSync(), isFalse);
    });

    test('Content-only template generates directory structure with zero process spawn', () async {
      int processCount = 0;
      Future<ProcessResult> recordingRunner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
        processCount++;
        return ProcessResult(0, 0, 'ok', '');
      }

      final service = PluginTemplateGeneratorService(
        projectRoot: projectRoot,
        editorApiRoot: editorApiRoot,
        runner: recordingRunner,
      );

      final spec = PluginTemplateSpec(
        templateType: PluginTemplateType.contentOnly,
        name: 'dungeon_props',
        friendlyName: 'Dungeon Props',
        category: 'Content',
      );

      final result = await service.generate(spec);

      expect(result.success, isTrue);
      expect(processCount, equals(0)); // Zero process spawn

      final pluginDir = result.pluginDir!;
      expect(Directory('${pluginDir.path}/content/materials').existsSync(), isTrue);
      expect(Directory('${pluginDir.path}/content/meshes').existsSync(), isTrue);
      expect(Directory('${pluginDir.path}/content/textures').existsSync(), isTrue);
      expect(File('${pluginDir.path}/dungeon_props.lmplugin').existsSync(), isTrue);
      // Content-only plugins have no pubspec; the dart:-only script still runs.
      expect(File('${pluginDir.path}/$kPluginPackScriptPath').readAsStringSync(), kPluginPackScript);
      final pack = await Process.run('dart', ['run', kPluginPackScriptPath],
          workingDirectory: pluginDir.path, runInShell: Platform.isWindows);
      expect(pack.exitCode, 0, reason: '${pack.stdout}\n${pack.stderr}');
      expect(File('${pluginDir.path}/build/pack/dungeon_props-0.1.0.zip').existsSync(), isTrue);

      final repo = PluginRepository(roots: [
        PluginScanRoot(dir: Directory('${projectRoot.path}/plugins'), origin: PluginOrigin.project),
      ]);
      final desc = await repo.load(File('${pluginDir.path}/dungeon_props.lmplugin'));
      expect(desc.name, equals('dungeon_props'));
      expect(desc.isContentOnly, isTrue);
      expect(desc.modules, isEmpty);
      expect(desc.canContainContent, isTrue);
    });

    test('Editor panel template registers panel with widget counter button', () async {
      Future<ProcessResult> runner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
        if (args.contains('create')) {
          Directory(args.last).createSync(recursive: true);
        }
        return ProcessResult(0, 0, 'ok', '');
      }

      final service = PluginTemplateGeneratorService(
        projectRoot: projectRoot,
        editorApiRoot: editorApiRoot,
        runner: runner,
      );

      final spec = PluginTemplateSpec(
        templateType: PluginTemplateType.editorPanel,
        name: 'custom_stats',
        friendlyName: 'Custom Stats',
        category: 'Profiling',
      );

      final result = await service.generate(spec);
      expect(result.success, isTrue);

      final source = File('${result.pluginDir!.path}/lib/src/custom_stats_plugin.dart').readAsStringSync();
      expect(source, contains('registerPanel'));
      expect(source, contains('CustomStatsPanelWidget'));
      expect(source, contains('PrimaryButton'));
      expect(source, contains('Count:'));
    });

    test('Importer template writes .txt importer with LuminaAsset .lmas serialization', () async {
      Future<ProcessResult> runner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
        if (args.contains('create')) {
          Directory(args.last).createSync(recursive: true);
        }
        return ProcessResult(0, 0, 'ok', '');
      }

      final service = PluginTemplateGeneratorService(
        projectRoot: projectRoot,
        editorApiRoot: editorApiRoot,
        runner: runner,
      );

      final spec = PluginTemplateSpec(
        templateType: PluginTemplateType.importer,
        name: 'notes_importer',
        friendlyName: 'Notes Importer',
        category: 'Pipeline',
      );

      final result = await service.generate(spec);
      expect(result.success, isTrue);

      final pubspec = File('${result.pluginDir!.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('  lumina:\n    git:\n      url: $kLuminaGitUrl\n      path: lumina\n'));

      final source = File('${result.pluginDir!.path}/lib/src/notes_importer_plugin.dart').readAsStringSync();
      expect(source, contains('registerImporter'));
      expect(source, contains("extensions: const ['.txt']"));
      expect(source, contains('LuminaAsset('));
      expect(source, contains('.lmas'));
    });

    test('Verify-stage failure rolls back and deletes generated plugin directory', () async {
      Future<ProcessResult> failingRunner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
        if (args.contains('create')) {
          Directory(args.last).createSync(recursive: true);
          return ProcessResult(0, 0, 'ok', '');
        }
        if (args.contains('analyze')) {
          return ProcessResult(0, 1, '', 'Error: Missing semicolon at line 10');
        }
        return ProcessResult(0, 0, 'ok', '');
      }

      final service = PluginTemplateGeneratorService(
        projectRoot: projectRoot,
        editorApiRoot: editorApiRoot,
        runner: failingRunner,
      );

      final spec = PluginTemplateSpec(
        templateType: PluginTemplateType.blank,
        name: 'broken_plugin',
        friendlyName: 'Broken Plugin',
      );

      final result = await service.generate(spec);
      expect(result.success, isFalse);
      expect(result.failureOutput, contains('Error: Missing semicolon'));

      final expectedDir = Directory('${projectRoot.path}/plugins/broken_plugin');
      expect(expectedDir.existsSync(), isFalse); // Proven rollback on disk
    });

    test('Name validation handles Dart package rules, reserved words, and collisions', () {
      final existingNames = ['water_system', 'mesh_tools'];
      final pluginsDir = Directory('${projectRoot.path}/plugins')..createSync(recursive: true);
      Directory('${pluginsDir.path}/existing_dir').createSync();

      expect(PluginTemplateGeneratorService.validatePluginName('my_plugin'), isNull);
      expect(PluginTemplateGeneratorService.validatePluginName('water2_system'), isNull);

      // Invalid format / characters
      expect(PluginTemplateGeneratorService.validatePluginName('MyPlugin'), contains('lowercase'));
      expect(PluginTemplateGeneratorService.validatePluginName('1plugin'), contains('start with a lowercase letter'));
      expect(PluginTemplateGeneratorService.validatePluginName('plugin-name'), contains('alphanumeric and underscore'));

      // Reserved keywords
      expect(PluginTemplateGeneratorService.validatePluginName('class'), contains('reserved Dart keyword'));
      expect(PluginTemplateGeneratorService.validatePluginName('import'), contains('reserved Dart keyword'));
      expect(PluginTemplateGeneratorService.validatePluginName('flutter'), contains('reserved package name'));
      expect(PluginTemplateGeneratorService.validatePluginName('lumina'), contains('reserved package name'));
      expect(PluginTemplateGeneratorService.validatePluginName('lumina_editor_api'), contains('reserved package name'));
      expect(PluginTemplateGeneratorService.validatePluginName('test'), contains('reserved package name'));

      // Collisions
      expect(PluginTemplateGeneratorService.validatePluginName('water_system', existingPluginNames: existingNames), contains('already exists'));
      expect(PluginTemplateGeneratorService.validatePluginName('existing_dir', scanRoots: [pluginsDir]), contains('directory already exists'));
    });

    test('without a local editor API the plugin depends on git only', () async {
      final service = PluginTemplateGeneratorService(
        projectRoot: projectRoot,
        runner: (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
          if (args.contains('create')) Directory(args.last).createSync(recursive: true);
          return ProcessResult(0, 0, 'ok', '');
        },
      );
      final result = await service.generate(const PluginTemplateSpec(
        templateType: PluginTemplateType.blank,
        name: 'git_only',
        friendlyName: 'Git Only',
        description: 'No local engine',
      ));
      expect(result.success, isTrue, reason: result.failureOutput);
      expect(File('${result.pluginDir!.path}/pubspec.yaml').readAsStringSync(), contains('url: $kLuminaGitUrl'));
      expect(File('${result.pluginDir!.path}/pubspec_overrides.yaml').existsSync(), isFalse);
    });

    test('local overrides pin the whole engine closure of the real workspace, tools packages included', () {
      final realEditorApiDir = Directory('${Directory.current.parent.path}/lumina_editor_api');
      if (!realEditorApiDir.existsSync()) return;
      final pluginDir = Directory('${projectRoot.path}/plugins/x')..createSync(recursive: true);
      final overrides = PluginTemplateGeneratorService.localEngineOverrides(realEditorApiDir, pluginDir);
      for (final name in ['lumina_editor_api', 'lumina', 'flutter_filament', 'flutter_assimp', 'flutter_riglogic', 'flutter_gstreamer', 'lumina_smoke', 'lumina_mouse_capture']) {
        expect(overrides, contains('  $name:\n    path: '), reason: name);
      }
    });

    test('Helper functions derive PascalCase and Friendly names correctly', () {
      expect(PluginTemplateGeneratorService.nameToPascal('water_system'), equals('WaterSystem'));
      expect(PluginTemplateGeneratorService.nameToPascal('water_2_system'), equals('Water2System'));
      expect(PluginTemplateGeneratorService.nameToPascal('hello'), equals('Hello'));

      expect(PluginTemplateGeneratorService.nameToFriendly('water_system'), equals('Water System'));
      expect(PluginTemplateGeneratorService.nameToFriendly('water_2_system'), equals('Water 2 System'));
      expect(PluginTemplateGeneratorService.nameToFriendly('hello'), equals('Hello'));
    });

    test('Real process generator verify stage passes pub get and analyze', () async {
      final realEditorApiDir = Directory('${Directory.current.parent.path}/lumina_editor_api');
      if (!realEditorApiDir.existsSync()) {
        return; // Skip if environment is different
      }

      final service = PluginTemplateGeneratorService(
        projectRoot: projectRoot,
        editorApiRoot: realEditorApiDir,
      );

      final spec = PluginTemplateSpec(
        templateType: PluginTemplateType.blank,
        name: 'real_test_plugin',
        friendlyName: 'Real Test Plugin',
        description: 'Testing real compilation',
      );

      final result = await service.generate(spec);
      expect(result.success, isTrue, reason: result.failureOutput);
      expect(result.pluginDir, isNotNull);
      expect(result.pluginDir!.existsSync(), isTrue);

      // The generated plugin packs itself for the marketplace.
      // `dart <script>`: no pub resolution / build hooks (the plugin depends on
      // lumina, whose hooks `dart run` would run first).
      final pack = await Process.run('dart', [kPluginPackScriptPath],
          workingDirectory: result.pluginDir!.path, runInShell: Platform.isWindows);
      expect(pack.exitCode, 0, reason: '${pack.stdout}\n${pack.stderr}');
      expect(pack.stderr as String, isNot(contains('Warning')), reason: 'the changelog has the 0.1.0 section');
      expect(File('${result.pluginDir!.path}/build/pack/real_test_plugin-0.1.0.zip').existsSync(), isTrue);
    }, tags: ['process']);

    // Every template that writes widget code must survive the real
    // `dart analyze --fatal-infos` (shadcn_flutter exports its own Row and
    // Column, which clash with package:flutter/widgets.dart).
    for (final type in [PluginTemplateType.editorPanel, PluginTemplateType.importer]) {
      test('Real process: the ${type.name} template passes pub get and analyze', () async {
        final realEditorApiDir = Directory('${Directory.current.parent.path}/lumina_editor_api');
        if (!realEditorApiDir.existsSync()) return;
        final service = PluginTemplateGeneratorService(projectRoot: projectRoot, editorApiRoot: realEditorApiDir);
        final result = await service.generate(PluginTemplateSpec(
          templateType: type,
          name: 'real_${type.name.toLowerCase()}_plugin',
          friendlyName: 'Real ${type.name}',
          description: 'Testing real compilation of the ${type.name} template',
        ));
        expect(result.success, isTrue, reason: result.failureOutput);
      }, tags: ['process'], timeout: const Timeout(Duration(minutes: 5)));
    }

    // Both halves of an isolated plugin compile against the real API, and the
    // tests it ships pass.
    for (final type in [PluginTemplateType.editorPanel, PluginTemplateType.importer]) {
      test('Real process: the isolated ${type.name} template passes analyze and its own tests', () async {
        final realEditorApiDir = Directory('${Directory.current.parent.path}/lumina_editor_api');
        if (!realEditorApiDir.existsSync()) return;
        final service = PluginTemplateGeneratorService(projectRoot: projectRoot, editorApiRoot: realEditorApiDir);
        final result = await service.generate(PluginTemplateSpec(
          templateType: type,
          name: 'iso_${type.name.toLowerCase()}_plugin',
          friendlyName: 'Isolated ${type.name}',
          description: 'Testing the isolated ${type.name} template',
          isolated: true,
        ));
        expect(result.success, isTrue, reason: result.failureOutput);
        final tests = await Process.run('flutter', ['test'],
            workingDirectory: result.pluginDir!.path, runInShell: Platform.isWindows);
        expect(tests.exitCode, 0, reason: '${tests.stdout}\n${tests.stderr}');
        expect('${tests.stdout}', contains('All tests passed'));
      }, tags: ['process'], timeout: const Timeout(Duration(minutes: 10)));
    }
  });
}
