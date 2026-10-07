import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/src/repositories/project_repository.dart';
import 'package:lumina_editor_data/src/services/plugin_template/code_plugin_sources.dart';
import 'package:yaml/yaml.dart';

export 'package:lumina_editor_data/src/repositories/project_repository.dart' show ProcessRunner;
// The lumina repo generated plugins take `lumina_editor_api` (and, for
// importers, `lumina`) from; defined beside the workspace paths.
export 'package:lumina_core/src/services/workspace_paths.dart' show kLuminaGitUrl;

enum PluginTemplateType {
  blank,
  contentOnly,
  editorPanel,
  importer,
}

class PluginTemplateSpec {
  final PluginTemplateType templateType;
  final String name;
  final String friendlyName;
  final String author;
  final String description;
  final String category;

  /// Scaffolds an isolated plugin (`.lmplugin` `"isolation": "process"`):
  /// a process part (`lib/src/<name>_process.dart`, a `LuminaPluginProcess`
  /// named as the module's `process_class`) that runs in its own process,
  /// and a UI shell (`lib/src/<name>_plugin.dart`) whose panel calls it
  /// through the plugin's channel. With [PluginTemplateType.importer] the
  /// importer runs in the process part. Not for content-only plugins.
  final bool isolated;

  const PluginTemplateSpec({
    required this.templateType,
    required this.name,
    required this.friendlyName,
    this.author = '',
    this.description = '',
    this.category = 'Other',
    this.isolated = false,
  });
}

class PluginGenerationResult {
  final bool success;
  final Directory? pluginDir;
  final LuminaPluginDescriptor? descriptor;
  final List<String> log;
  final String? failureOutput;

  const PluginGenerationResult({
    required this.success,
    this.pluginDir,
    this.descriptor,
    this.log = const [],
    this.failureOutput,
  });

  factory PluginGenerationResult.success({
    required Directory pluginDir,
    required LuminaPluginDescriptor descriptor,
    List<String> log = const [],
  }) =>
      PluginGenerationResult(
        success: true,
        pluginDir: pluginDir,
        descriptor: descriptor,
        log: log,
      );

  factory PluginGenerationResult.failure({
    required String failureOutput,
    Directory? pluginDir,
    List<String> log = const [],
  }) =>
      PluginGenerationResult(
        success: false,
        pluginDir: pluginDir,
        failureOutput: failureOutput,
        log: log,
      );
}

/// The shadcn_flutter version Lumina Studio (lumina_ui/pubspec.lock) resolves.
/// Generated plugins pin it exactly so they compile against the host's copy.
const String kHostShadcnFlutterVersion = '0.0.55';


class PluginTemplateGeneratorService {
  final Directory projectRoot;

  /// A local `lumina_editor_api` checkout. The generated pubspec always
  /// depends on the engine through git ([kLuminaGitUrl]); with a local
  /// checkout the plugin also gets a (gitignored) `pubspec_overrides.yaml`
  /// pinning `lumina_editor_api`, `lumina` and their path/git dependencies
  /// to it, so it resolves and verifies against the running engine. Null: git
  /// only.
  final Directory? editorApiRoot;
  final ProcessRunner runner;
  final void Function(String message)? onLog;

  PluginTemplateGeneratorService({
    required this.projectRoot,
    this.editorApiRoot,
    ProcessRunner? runner,
    this.onLog,
  }) : runner = runner ??
            ((String exec, List<String> args,
                    {String? workingDirectory, bool runInShell = false}) =>
                Process.run(exec, args,
                    workingDirectory: workingDirectory,
                    runInShell: runInShell || Platform.isWindows));

  static const List<String> _reservedKeywords = [
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'base',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'of',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'sealed',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'when',
    'while',
    'with',
    'yield',
  ];

  static const List<String> _reservedPackageNames = [
    'flutter',
    'flutter_test',
    'lumina',
    'lumina_core',
    'lumina_editor_data',
    'lumina_widgets',
    'lumina_ui',
    'lumina_editor_api',
    'test',
  ];

  static String? validatePluginName(
    String name, {
    List<String> existingPluginNames = const [],
    List<Directory> scanRoots = const [],
  }) {
    if (name.isEmpty) {
      return 'Plugin name cannot be empty.';
    }
    if (name.length > 64) {
      return 'Plugin name must be 64 characters or less.';
    }
    if (!RegExp(r'^[a-z]').hasMatch(name)) {
      return 'Plugin name must start with a lowercase letter [a-z].';
    }
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      return 'Plugin name may only contain lowercase alphanumeric and underscore characters.';
    }
    if (_reservedKeywords.contains(name)) {
      return 'Plugin name "$name" is a reserved Dart keyword.';
    }
    if (_reservedPackageNames.contains(name)) {
      return 'Plugin name "$name" is a reserved package name.';
    }
    if (existingPluginNames.contains(name)) {
      return 'A plugin named "$name" already exists in the project.';
    }
    for (final root in scanRoots) {
      if (root.existsSync()) {
        final targetDir = Directory(p.join(root.path, name));
        if (targetDir.existsSync()) {
          return 'A plugin directory already exists at ${targetDir.path}.';
        }
      }
    }
    return null;
  }

  static String nameToFriendly(String name) {
    if (name.isEmpty) return '';
    final parts = name.split('_');
    final capitalized = parts.map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1);
    });
    return capitalized.join(' ');
  }

  static String nameToPascal(String name) {
    if (name.isEmpty) return '';
    final parts = name.split('_');
    final capitalized = parts.map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1);
    });
    return capitalized.join('');
  }

  /// A `pubspec_overrides.yaml` pinning the engine packages a plugin in
  /// [pluginDir] depends on to the local checkout holding [editorApiRoot]:
  /// `lumina_editor_api` and every package of its path/git closure
  /// (`lumina`, `flutter_filament`, the tools packages, …), as POSIX paths
  /// relative to [pluginDir] (`path_not_posix` fails analyze on Windows
  /// otherwise). The closure's git dependencies come from the checkout's
  /// resolved package config; when it has none, only `lumina_editor_api`
  /// and the `lumina` beside it are pinned.
  static String localEngineOverrides(Directory editorApiRoot, Directory pluginDir, {void Function(String)? onLog}) {
    final apiDir = p.normalize(editorApiRoot.absolute.path);
    final engineRoot = p.dirname(apiDir);
    final packages = <String, String>{};
    try {
      final sources = EditorSourceVendorService(engineRoot: engineRoot, rootPackage: p.basename(apiDir)).packageSources();
      for (final dir in sources.values) {
        final yaml = loadYaml(File(p.join(dir, 'pubspec.yaml')).readAsStringSync());
        final name = yaml is YamlMap ? yaml['name'] : null;
        if (name != null) packages['$name'] = dir;
      }
    } on Exception catch (e) {
      onLog?.call('Could not resolve the engine closure of $apiDir ($e); pinning lumina_editor_api and lumina only');
    } on StateError catch (e) {
      onLog?.call('Could not resolve the engine closure of $apiDir (${e.message}); pinning lumina_editor_api and lumina only');
    }
    packages.putIfAbsent('lumina_editor_api', () => apiDir);
    final lumina = p.join(engineRoot, 'lumina');
    if (File(p.join(lumina, 'pubspec.yaml')).existsSync()) packages.putIfAbsent('lumina', () => lumina);

    final b = StringBuffer()
      ..writeln('# Local development: the engine checkout this plugin was generated')
      ..writeln('# against, instead of the git dependencies in pubspec.yaml. Delete this')
      ..writeln('# file to build against $kLuminaGitUrl.')
      ..writeln('dependency_overrides:');
    for (final name in packages.keys.toList()..sort()) {
      final rel = p.relative(packages[name]!, from: pluginDir.absolute.path).replaceAll(r'\', '/');
      b
        ..writeln('  $name:')
        ..writeln("    path: '$rel'");
    }
    return b.toString();
  }

  Future<PluginGenerationResult> generate(PluginTemplateSpec spec) async {
    final log = <String>[];
    void emit(String msg) {
      log.add(msg);
      onLog?.call(msg);
    }

    final pluginsDir = Directory(p.join(projectRoot.path, 'plugins'));
    final targetDir = Directory(p.join(pluginsDir.path, spec.name));

    final validationError = spec.isolated && spec.templateType == PluginTemplateType.contentOnly
        ? 'A content-only plugin has no code to run in its own process.'
        : validatePluginName(
            spec.name,
            scanRoots: [pluginsDir],
          );
    if (validationError != null) {
      emit('Validation error: $validationError');
      return PluginGenerationResult.failure(
        failureOutput: validationError,
        log: log,
      );
    }

    emit('Starting generation of plugin "${spec.name}" (${spec.templateType.name}${spec.isolated ? ', isolated' : ''})...');

    try {
      if (!pluginsDir.existsSync()) {
        pluginsDir.createSync(recursive: true);
      }

      // Stage 1: Scaffold
      if (spec.templateType == PluginTemplateType.contentOnly) {
        emit('Scaffolding content-only directories...');
        targetDir.createSync(recursive: true);
        Directory(p.join(targetDir.path, 'content', 'materials')).createSync(recursive: true);
        Directory(p.join(targetDir.path, 'content', 'meshes')).createSync(recursive: true);
        Directory(p.join(targetDir.path, 'content', 'textures')).createSync(recursive: true);
        Directory(p.join(targetDir.path, 'resources')).createSync(recursive: true);
      } else {
        emit('Scaffolding Dart package using flutter/dart create...');
        targetDir.createSync(recursive: true);
        var createResult = await runner(
          'flutter',
          [
            'create',
            '--template=package',
            '--project-name',
            spec.name,
            targetDir.path,
          ],
          workingDirectory: pluginsDir.path,
        );

        if (createResult.exitCode != 0) {
          emit('flutter create failed or not found, attempting dart create fallback...');
          createResult = await runner(
            'dart',
            [
              'create',
              '-t',
              'package',
              '--project-name',
              spec.name,
              targetDir.path,
            ],
            workingDirectory: pluginsDir.path,
          );
        }

        if (createResult.exitCode != 0) {
          emit('Package scaffolding failed: ${createResult.stderr}');
        }
      }

      // Clean scaffold boilerplate
      final defaultTestFile = File(p.join(targetDir.path, 'test', '${spec.name}_test.dart'));
      if (defaultTestFile.existsSync()) {
        defaultTestFile.deleteSync();
      }

      // Stage 2: Patch pubspec
      if (spec.templateType != PluginTemplateType.contentOnly) {
        emit('Emitting custom pubspec.yaml...');
        final pubspecBuffer = StringBuffer();
        pubspecBuffer.writeln('name: ${spec.name}');
        pubspecBuffer.writeln('description: "${spec.description.replaceAll('"', '\\"')}"');
        pubspecBuffer.writeln('version: 0.1.0');
        pubspecBuffer.writeln('publish_to: none');
        pubspecBuffer.writeln();
        pubspecBuffer.writeln('environment:');
        pubspecBuffer.writeln('  sdk: ^3.12.0');
        pubspecBuffer.writeln('  flutter: ">=1.17.0"');
        pubspecBuffer.writeln();
        pubspecBuffer.writeln('dependencies:');
        pubspecBuffer.writeln('  flutter:');
        pubspecBuffer.writeln('    sdk: flutter');
        // A release editor pins the engine commit it fetched its source at.
        final engineRef = LuminaWorkspace.engineCommit;
        void gitDependency(String name) {
          pubspecBuffer.writeln('  $name:');
          pubspecBuffer.writeln('    git:');
          pubspecBuffer.writeln('      url: ${LuminaWorkspace.engineRepo ?? kLuminaGitUrl}');
          pubspecBuffer.writeln('      path: $name');
          if (engineRef != null) pubspecBuffer.writeln('      ref: $engineRef');
        }

        gitDependency('lumina_editor_api');
        if (spec.templateType == PluginTemplateType.importer) {
          gitDependency('lumina');
        }
        // Pinned to the exact version Lumina Studio resolves: a plugin shares
        // the host's single shadcn_flutter copy, so a newer pub release (with
        // a different showOverlay/Dialog API) must never be picked here.
        pubspecBuffer.writeln('  shadcn_flutter: $kHostShadcnFlutterVersion');
        pubspecBuffer.writeln();
        pubspecBuffer.writeln('dev_dependencies:');
        pubspecBuffer.writeln('  flutter_test:');
        pubspecBuffer.writeln('    sdk: flutter');
        pubspecBuffer.writeln('  flutter_lints: ^6.0.0');
        pubspecBuffer.writeln('  test: ^1.24.0');
        pubspecBuffer.writeln();
        pubspecBuffer.writeln('flutter:');

        File(p.join(targetDir.path, 'pubspec.yaml')).writeAsStringSync(pubspecBuffer.toString());

        final apiRoot = editorApiRoot;
        if (apiRoot != null) {
          emit('Pointing lumina_editor_api at ${apiRoot.path} (pubspec_overrides.yaml)...');
          File(p.join(targetDir.path, 'pubspec_overrides.yaml'))
              .writeAsStringSync(localEngineOverrides(apiRoot, targetDir, onLog: emit));
          final gitignore = File(p.join(targetDir.path, '.gitignore'));
          final ignored = gitignore.existsSync() ? gitignore.readAsStringSync() : '';
          if (!ignored.split('\n').any((l) => l.trim() == 'pubspec_overrides.yaml')) {
            gitignore.writeAsStringSync(
                '${ignored.isEmpty || ignored.endsWith('\n') ? ignored : '$ignored\n'}'
                '# The local engine checkout this plugin was generated against.\npubspec_overrides.yaml\n');
          }
        }
      }

      // Stage 3: Emit source
      final pascalName = nameToPascal(spec.name);
      final cleanFriendlyName = (spec.friendlyName.isEmpty ? nameToFriendly(spec.name) : spec.friendlyName).replaceAll('/', ' ').trim();

      if (spec.templateType != PluginTemplateType.contentOnly) {
        emit('Emitting plugin source code...');
        final libDir = Directory(p.join(targetDir.path, 'lib'))..createSync(recursive: true);
        final srcDir = Directory(p.join(libDir.path, 'src'))..createSync(recursive: true);

        // lib/<name>.dart
        final entryContent = spec.isolated
            ? IsolatedPluginSources.entryLibrary(spec.name)
            : '''// GENERATED BY LUMINA PLUGIN WIZARD
library;

export 'src/${spec.name}_plugin.dart';
''';
        File(p.join(libDir.path, '${spec.name}.dart')).writeAsStringSync(entryContent);

        // lib/src/<name>_plugin.dart (an isolated plugin's UI shell)
        final pluginContent = spec.isolated
            ? IsolatedPluginSources.shellSource(
                pluginName: spec.name,
                pascalName: pascalName,
                friendlyName: cleanFriendlyName,
                description: spec.description,
              )
            : CodePluginSources.pluginSource(
                templateType: spec.templateType,
                pluginName: spec.name,
                pascalName: pascalName,
                friendlyName: cleanFriendlyName,
                description: spec.description,
              );
        File(p.join(srcDir.path, '${spec.name}_plugin.dart')).writeAsStringSync(pluginContent);

        // lib/src/<name>_process.dart: what runs in the plugin's own process.
        if (spec.isolated) {
          File(p.join(srcDir.path, '${spec.name}_process.dart')).writeAsStringSync(IsolatedPluginSources.processSource(
            pluginName: spec.name,
            pascalName: pascalName,
            friendlyName: cleanFriendlyName,
            importer: spec.templateType == PluginTemplateType.importer,
          ));
        }
      }

      // Stage 4: Manifest
      emit('Writing .lmplugin manifest...');
      final manifestJson = <String, dynamic>{
        'name': spec.name,
        'friendly_name': cleanFriendlyName,
        'version': '0.1.0',
        'description': spec.description,
        'category': spec.category.isEmpty ? 'Other' : spec.category,
        if (spec.author.isNotEmpty) 'authors': [spec.author],
        'engine_version': '>=0.0.1 <1.0.0',
        'can_contain_content': spec.templateType == PluginTemplateType.contentOnly,
        if (spec.isolated) 'isolation': PluginIsolation.process.manifestValue,
        'modules': spec.templateType == PluginTemplateType.contentOnly
            ? <dynamic>[]
            : <dynamic>[
                {
                  'name': spec.name,
                  'type': 'editor',
                  'entry_library': 'lib/${spec.name}.dart',
                  'registration_class': '${pascalName}Plugin',
                  if (spec.isolated) 'process_class': '${pascalName}Process',
                }
              ],
      };
      File(p.join(targetDir.path, '${spec.name}.lmplugin'))
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifestJson));

      // Stage 5: Extras
      emit('Generating icon, test fixture, README and pack script...');
      final resourcesDir = Directory(p.join(targetDir.path, 'resources'))..createSync(recursive: true);
      final rgba = Uint8List(128 * 128 * 4);
      for (var i = 0; i < 128 * 128; i++) {
        final px = i % 128;
        final py = i ~/ 128;
        rgba[i * 4] = (60 + (px % 40)).clamp(0, 255);
        rgba[i * 4 + 1] = (120 + (py % 60)).clamp(0, 255);
        rgba[i * 4 + 2] = 200;
        rgba[i * 4 + 3] = 255;
      }
      final pngBytes = TgaDecoderService.encodePng(rgba, 128, 128);
      File(p.join(resourcesDir.path, 'icon128.png')).writeAsBytesSync(pngBytes);

      // README
      final readmeContent = '''# $cleanFriendlyName

${spec.description}

## Template
Generated with template: **${spec.templateType.name}**${spec.isolated ? '''
(isolated: runs in its own process)

## Two halves
- `lib/src/${spec.name}_process.dart` (`${pascalName}Process`, the manifest's
  `process_class`) runs in its own process. Native (FFI) libraries, child
  processes, network calls and heavy work live here: if it crashes or hangs,
  the editor keeps running and offers Restart.
- `lib/src/${spec.name}_plugin.dart` (`${pascalName}Plugin`) is the UI shell
  inside the editor. It calls the process part through
  `context.processChannel('${spec.name}')` (`call`, `events`, `progress`,
  `state`, `restart`).
- Project Settings can force the plugin in process for debugging
  (`.lmproject` `plugin_isolation`).''' : ''}

## Enabling the Plugin
1. Open Lumina Studio.
2. Go to **Tools -> Plugins**.
3. Find **$cleanFriendlyName** and toggle the enable switch.
4. If code changes were made, restart the editor for the plugin to take effect.

## Publishing on the Lumina Marketplace
Publish: `dart run $kPluginPackScriptPath`, then upload `build/pack/*.zip`.

The script writes `build/pack/${spec.name}-<version>.zip` (the manifest's
version, which must equal `pubspec.yaml`'s) without build outputs, IDE
folders, logs, secrets and ignored files, and refuses what the marketplace
would refuse. Upload the zip under **Publish -> Plugin** on the marketplace. List
more files to leave out (e.g. `test/`) in a `.pubignore`; `--dry-run` shows
what goes in.
''';
      File(p.join(targetDir.path, 'README.md')).writeAsStringSync(readmeContent);

      // CHANGELOG.md with the manifest version's section: the marketplace's
      // release notes (flutter create's stub names 0.0.1).
      File(p.join(targetDir.path, 'CHANGELOG.md')).writeAsStringSync('## 0.1.0\n\n- Initial release.\n');

      // tool/pack_plugin.dart: packs the plugin for the marketplace.
      File(p.join(targetDir.path, 'tool', kPluginPackScriptFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync(kPluginPackScript);

      // Test file for code plugins
      if (spec.templateType != PluginTemplateType.contentOnly) {
        final testDir = Directory(p.join(targetDir.path, 'test'))..createSync(recursive: true);
        final testContent = spec.isolated
            ? IsolatedPluginSources.shellTest(pluginName: spec.name, pascalName: pascalName)
            : CodePluginSources.pluginTest(
                pluginName: spec.name,
                pascalName: pascalName,
              );
        File(p.join(testDir.path, '${spec.name}_plugin_test.dart')).writeAsStringSync(testContent);
        if (spec.isolated) {
          File(p.join(testDir.path, '${spec.name}_process_test.dart'))
              .writeAsStringSync(IsolatedPluginSources.processTest(pluginName: spec.name, pascalName: pascalName));
        }
      }

      // Stage 6: Verify
      if (spec.templateType != PluginTemplateType.contentOnly) {
        emit('Running verify stage: dart pub get & dart analyze...');
        final pubGetRes = await runner(
          'dart',
          ['pub', 'get'],
          workingDirectory: targetDir.path,
        );
        if (pubGetRes.exitCode != 0) {
          emit('Verify failed on pub get: ${pubGetRes.stderr}');
        }

        final analyzeRes = await runner(
          'dart',
          ['analyze', '--fatal-infos'],
          workingDirectory: targetDir.path,
        );
        if (analyzeRes.exitCode != 0) {
          emit('Verify failed on analyze: ${analyzeRes.stdout}\n${analyzeRes.stderr}');
          // Clean rollback
          if (targetDir.existsSync()) {
            targetDir.deleteSync(recursive: true);
          }
          return PluginGenerationResult.failure(
            failureOutput: '${analyzeRes.stdout}\n${analyzeRes.stderr}'.trim(),
            log: log,
          );
        }
      }

      // Load descriptor
      final repo = PluginRepository(roots: [
        PluginScanRoot(dir: pluginsDir, origin: PluginOrigin.project),
      ]);
      final descriptor = await repo.load(File(p.join(targetDir.path, '${spec.name}.lmplugin')));

      emit('Plugin "${spec.name}" successfully generated.');
      return PluginGenerationResult.success(
        pluginDir: targetDir,
        descriptor: descriptor,
        log: log,
      );
    } catch (e, st) {
      emit('Unexpected generation failure: $e\n$st');
      if (targetDir.existsSync()) {
        targetDir.deleteSync(recursive: true);
      }
      return PluginGenerationResult.failure(
        failureOutput: e.toString(),
        log: log,
      );
    }
  }
}
