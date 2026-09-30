import 'dart:convert';
import 'dart:io';

import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/services/code_generator_service.dart';
import 'package:lumina/data/services/plugin_host_patcher_service.dart';
import 'package:lumina/data/services/editor_source_vendor_service.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// What [EditorHostGeneratorService.generate] did.
enum EditorHostStatus {
  /// `<project>/.lumina/editor/` holds the project's editor host.
  generated,
}

class EditorHostResult {
  final EditorHostStatus status;

  /// `<project>/.lumina/editor`, when [status] is [EditorHostStatus.generated].
  final Directory? hostDir;

  /// The host package's name (`<project_snake>_editor`), also its binary name.
  final String? packageName;

  /// Whether any generated file differed from what was on disk.
  final bool changed;

  const EditorHostResult._(this.status, this.hostDir, this.packageName, this.changed);

  factory EditorHostResult.generated(Directory hostDir, String packageName, {required bool changed}) =>
      EditorHostResult._(EditorHostStatus.generated, hostDir, packageName, changed);
}

/// Writes a project's editor host package: a thin Flutter app in
/// `<project>/.lumina/editor/` that depends on `lumina_ui` as a library plus
/// the project's code plugins, and holds its own registrar and platform
/// runner. Every engine package it depends on is the
/// project's own copy beside it (`lumina_ui/`, `lumina/`, …, made by
/// `EditorSourceVendorService`), referenced by relative paths. The engine
/// checkout is never modified.
///
/// Output is deterministic (the same inputs give byte-identical files) and
/// written in place: a regeneration that changes nothing leaves the folder —
/// the source copy, `.dart_tool`, `pubspec.lock` and build stamp — untouched.
class EditorHostGeneratorService {
  /// The workspace root holding `lumina_ui/`, `lumina/`, `flutter_filament/`, ….
  final String engineRoot;

  /// The host OS whose runner folder is copied (`linux`, `windows`, `macos`).
  final String platform;

  /// The workspace whose `pubspec.lock` pinned the git-resolved plugins
  /// (the engine's built-ins); defaults to [engineRoot].
  final String workspaceRoot;

  EditorHostGeneratorService({required this.engineRoot, String? platform, String? workspaceRoot})
      : platform = platform ?? Platform.operatingSystem,
        workspaceRoot = workspaceRoot ?? engineRoot;

  /// The stamp file the build service writes into the host after a build.
  static const String stampFileName = '.lumina_editor_stamp.json';

  static String hostDirOf(String projectDir) => p.join(projectDir, '.lumina', 'editor');

  /// `MyGame` → `my_game_editor`, always a valid Dart package name.
  static String packageNameFor(String projectName) {
    var snake = DartCodeGeneratorService.snakeCaseFileName(projectName);
    if (snake.isEmpty || RegExp(r'^[0-9]').hasMatch(snake)) snake = 'project_$snake';
    return '${snake.replaceAll(RegExp(r'_+$'), '')}_editor';
  }

  /// The plugins that contribute editor code (the ones a host must compile).
  static List<LuminaPluginDescriptor> editorCodePlugins(List<LuminaPluginDescriptor> plugins) {
    final list = plugins
        .where((d) => !d.isContentOnly && d.modules.any((m) => m.type == PluginModuleType.editor))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// The project's name: the `.lmproject` file's base name.
  static String? projectNameIn(String projectDir) {
    final dir = Directory(projectDir);
    if (!dir.existsSync()) return null;
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.lmproject')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files.isEmpty ? null : p.basenameWithoutExtension(files.first.path);
  }

  Future<EditorHostResult> generate(String projectDir, List<LuminaPluginDescriptor> enabledCodePlugins, {String? projectName}) async {
    final hostDir = Directory(hostDirOf(projectDir));

    // A project without code plugins still gets its
    // own editor — the same host with an empty registrar.
    final plugins = editorCodePlugins(enabledCodePlugins);

    final name = projectName ?? projectNameIn(projectDir) ?? p.basename(projectDir);
    final packageName = packageNameFor(name);
    final files = <String, List<int>>{
      'pubspec.yaml': _utf8(_pubspec(name, packageName, plugins)),
      'lib/main.dart': _utf8(_main(packageName)),
      'lib/plugin_registrar.dart': _utf8(PluginHostPatcherService().registrarSource(plugins)),
      ..._runner(packageName, name, hostDir.path),
    };

    // A host resolved against the engine checkout (absolute
    // paths) starts over against the project's copy: its resolution and
    // build are dropped; the build stamp stays, so the rebuild has a reason.
    var changed = false;
    if (isOldLayout(hostDir.path)) {
      for (final stale in ['.dart_tool', 'build']) {
        final d = Directory(p.join(hostDir.path, stale));
        if (d.existsSync()) await d.delete(recursive: true);
      }
      for (final stale in ['pubspec.lock', '.flutter-plugins-dependencies']) {
        final f = File(p.join(hostDir.path, stale));
        if (f.existsSync()) await f.delete();
      }
      changed = true;
    }

    // In place, never by swapping the folder: it also holds the project's
    // copy of the engine source, the lock and the stamp.
    for (final entry in files.entries) {
      final f = File(p.join(hostDir.path, entry.key));
      if (f.existsSync() && _sameBytes(f.readAsBytesSync(), entry.value)) continue;
      await f.parent.create(recursive: true);
      await f.writeAsBytes(entry.value, flush: true);
      changed = true;
    }
    // A runner file the engine dropped since the last generation.
    final runnerDir = Directory(p.join(hostDir.path, platform));
    if (runnerDir.existsSync()) {
      for (final f in runnerDir.listSync(recursive: true).whereType<File>()) {
        final rel = p.relative(f.path, from: hostDir.path).replaceAll(r'\', '/');
        if (_isFlutterGenerated(rel.substring(platform.length + 1))) continue;
        if (files.containsKey(rel)) continue;
        await f.delete();
        changed = true;
      }
    }
    return EditorHostResult.generated(hostDir, packageName, changed: changed);
  }

  /// Whether the host at [hostDir] depends on `lumina_ui` anywhere but the
  /// project's copy beside it (a host from before per-project source copies).
  static bool isOldLayout(String hostDir) {
    final f = File(p.join(hostDir, 'pubspec.yaml'));
    if (!f.existsSync()) return false;
    try {
      final yaml = loadYaml(f.readAsStringSync());
      final deps = yaml is YamlMap ? yaml['dependencies'] : null;
      final ui = deps is YamlMap ? deps['lumina_ui'] : null;
      return ui is YamlMap && ui['path'] != null && ui['path'].toString() != 'lumina_ui';
    } on YamlException {
      return false;
    }
  }

  static List<int> _utf8(String s) => utf8.encode(s);

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String get _uiRoot => p.join(engineRoot, 'lumina_ui');

  static String _slash(String path) => p.normalize(path).replaceAll(r'\', '/');

  String _pubspec(String projectName, String packageName, List<LuminaPluginDescriptor> plugins) {
    final ui = loadYaml(File(p.join(_uiRoot, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
    final sdk = (ui['environment'] as YamlMap?)?['sdk']?.toString() ?? '^3.12.0';

    // Every package of lumina_ui's path closure, pinned to the project's copy
    // beside this pubspec by a relative path, so a plugin's own
    // `path: ../lumina_editor_api` (written for wherever it was authored)
    // resolves to the same packages the editor is built from, and the
    // project folder can move. Packages from other repos (git dependencies
    // such as flutter_assimp) are copied by name and pinned the same way.
    final overrides = <String, String>{};
    final sources = EditorSourceVendorService(engineRoot: engineRoot).packageSources();
    for (final MapEntry(key: rel, value: dir) in sources.entries) {
      if (rel == 'lumina_ui') continue;
      final yaml = loadYaml(File(p.join(dir, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
      overrides['${yaml['name']}'] = rel;
    }
    for (final plugin in plugins) {
      overrides.remove(plugin.name);
    }

    final b = StringBuffer()
      ..writeln('# GENERATED by Lumina Studio — do not edit.')
      ..writeln('# The editor for $projectName: the engine\'s lumina_ui plus the code')
      ..writeln('# plugins in its .lmproject enabled_plugins. Regenerated when missing.')
      ..writeln('name: $packageName')
      ..writeln('description: Lumina Studio editor for $projectName with its code plugins.')
      ..writeln("publish_to: 'none'")
      ..writeln('version: 0.0.1+1')
      ..writeln()
      ..writeln('environment:')
      ..writeln("  sdk: '$sdk'")
      ..writeln()
      ..writeln('dependencies:')
      ..writeln('  flutter:')
      ..writeln('    sdk: flutter')
      ..writeln('  lumina_ui:')
      ..writeln('    path: lumina_ui');
    if (overrides.containsKey('lumina_editor_api')) {
      b
        ..writeln('  lumina_editor_api:')
        ..writeln('    path: ${overrides['lumina_editor_api']}');
    }
    // A plugin the engine workspace resolved from git (a built-in, pinned
    // by commit in its pubspec.lock and fetched into the pub cache) is the
    // same git dependency here, never a path into the pub cache; any other
    // plugin is its folder.
    for (final plugin in plugins) {
      b.writeln('  ${plugin.name}:');
      final git = LuminaWorkspace.gitSourceOf(workspaceRoot, plugin.name, packageDir: plugin.pluginDir.path);
      if (git != null) {
        b
          ..writeln('    git:')
          ..writeln("      url: '${git.url}'");
        if (git.path != null) b.writeln("      path: '${git.path}'");
        b.writeln("      ref: '${git.ref}'");
      } else {
        b.writeln("    path: '${_slash(p.absolute(plugin.pluginDir.path))}'");
      }
    }
    b
      ..writeln()
      ..writeln('dependency_overrides:');
    for (final name in overrides.keys.toList()..sort()) {
      b
        ..writeln('  $name:')
        ..writeln('    path: ${overrides[name]}');
    }
    // The native-assets hooks' settings (read from the root pubspec, relative
    // to it): Filament is the host's `filament` link, the tools packages take
    // the bundled libc++ (Linux) from the copied flutter_filament, and
    // flutter_riglogic the prebuilt library of the host's `openriglogic` link
    // (a release checkout's); without that link the hook keeps the copied
    // package's own build.
    final hooked = [
      for (final name in ['flutter_filament', 'flutter_assimp', 'flutter_riglogic'])
        if (overrides.containsKey(name)) name,
    ];
    if (hooked.isNotEmpty) {
      b
        ..writeln()
        ..writeln('hooks:')
        ..writeln('  user_defines:');
      for (final name in hooked) {
        b
          ..writeln('    $name:')
          ..writeln('      filament_dir: ${EditorSourceVendorService.filamentDir}');
        if (name != 'flutter_filament' && overrides.containsKey('flutter_filament')) {
          b.writeln('      libcxx_dir: ${overrides['flutter_filament']}/third_party/libcxx');
        }
        if (name == 'flutter_riglogic') {
          b.writeln('      riglogic_lib_dir: ${EditorSourceVendorService.openriglogicDir}/lib');
        }
      }
    }
    b
      ..writeln()
      ..writeln('flutter:')
      ..writeln('  uses-material-design: true');
    return b.toString();
  }

  /// Project-agnostic: the project comes from `--project`, so projects with
  /// the same plugins share one build.
  String _main(String packageName) => '''
// GENERATED by Lumina Studio — do not edit.
import 'package:lumina_ui/editor_entry.dart';

import 'plugin_registrar.dart';

void main(List<String> args) => runLuminaEditor(
      args,
      plugins: kEnabledPlugins,
      host: const EditorHostInfo(
        packageName: '$packageName',
        engineRoot: r'${_slash(engineRoot)}',
      ),
    );
''';

  /// `flutter pub get` / `flutter build` write these; copying the engine's
  /// would register the stock editor's plugin set.
  static bool _isFlutterGenerated(String relInPlatform) =>
      relInPlatform.startsWith('flutter/ephemeral/') ||
      relInPlatform.startsWith('flutter/generated_plugin') ||
      relInPlatform == 'flutter/generated_plugins.cmake' ||
      relInPlatform.startsWith('Flutter/ephemeral/') ||
      relInPlatform.startsWith('Flutter/GeneratedPluginRegistrant') ||
      relInPlatform.startsWith('Pods/');

  static const _textExtensions = {'.txt', '.cc', '.cpp', '.h', '.rc', '.manifest', '.cmake', '.swift', '.plist', '.xcconfig', '.pbxproj', '.gitignore', ''};

  /// The engine's `<platform>/` runner folder with `lumina_ui` renamed to the
  /// host package (binary name, CMake project, Windows version resource,
  /// window title) and a per-project application id.
  Map<String, List<int>> _runner(String packageName, String projectName, String hostDir) {
    // From the project's copy of lumina_ui when it has one.
    final copied = Directory(p.join(hostDir, 'lumina_ui', platform));
    final src = copied.existsSync() ? copied : Directory(p.join(_uiRoot, platform));
    if (!src.existsSync()) return const {};
    final out = <String, List<int>>{};
    // Links are not followed: flutter/ephemeral/.plugin_symlinks leads into
    // other packages' trees (their build folders too), none of it runner.
    final files = src.listSync(recursive: true, followLinks: false).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final rel = p.relative(f.path, from: src.path).replaceAll(r'\', '/');
      if (_isFlutterGenerated(rel)) continue;
      final bytes = f.readAsBytesSync();
      final ext = p.extension(rel).toLowerCase();
      final isText = _textExtensions.contains(ext) && !bytes.contains(0);
      if (!isText) {
        out['$platform/$rel'] = bytes;
        continue;
      }
      // latin1 round-trips every byte, so only the ASCII names change.
      var text = latin1.decode(bytes);
      text = text
          .replaceAll('io.github.luminagame.LuminaStudio', 'io.github.luminagame.$packageName')
          .replaceAll('lumina_ui', packageName);
      out['$platform/$rel'] = latin1.encode(text);
    }
    return out;
  }
}
