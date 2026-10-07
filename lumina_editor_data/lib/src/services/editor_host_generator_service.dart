import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/services/code_generator_service.dart';
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
/// The host's `pubspec.lock` is seeded from the engine's (see
/// [engineLockOf]), so `pub get` resolves the versions the engine was built
/// with, never whatever pub.dev published since.
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
    var pubspecChanged = false;
    for (final entry in files.entries) {
      final f = File(p.join(hostDir.path, entry.key));
      if (f.existsSync() && _sameBytes(f.readAsBytesSync(), entry.value)) continue;
      await f.parent.create(recursive: true);
      await f.writeAsBytes(entry.value, flush: true);
      changed = true;
      if (entry.key == 'pubspec.yaml') pubspecChanged = true;
    }
    if (await _pinEngineLock(hostDir.path, force: pubspecChanged)) changed = true;
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

  /// The lock the host's hosted packages are pinned to: the project copy's
  /// snapshot of the engine lock (the versions that source was built and
  /// tested with), else the engine workspace's `pubspec.lock`.
  File engineLockOf(String hostDir) {
    final snapshot = File(p.join(hostDir, EditorSourceVendorService.engineLockFileName));
    return snapshot.existsSync() ? snapshot : File(p.join(workspaceRoot, 'pubspec.lock'));
  }

  /// The engine-locked hosted packages the host's `pubspec.lock` holds at
  /// another version (a code plugin's constraint moved them), as
  /// `name <engine> → <host>`.
  List<String> movedFromEngineLock(String hostDir) {
    final engine = _hostedEntries(_readLock(engineLockOf(hostDir)));
    final host = _readLock(File(p.join(hostDir, 'pubspec.lock')));
    final packages = host?['packages'];
    if (packages is! YamlMap) return const [];
    return [
      for (final MapEntry(key: name, value: pinned) in engine.entries)
        if (packages[name] case final YamlMap h when h['source'] == 'hosted' && '${h['version']}' != '${pinned['version']}')
          '$name ${pinned['version']} → ${h['version']}',
    ];
  }

  /// Seeds the host's `pubspec.lock` with every hosted package of
  /// [engineLockOf], so `pub get` keeps the engine's versions instead of
  /// resolving the newest ones (a new upstream release would otherwise
  /// reach every project editor). Packages only the host has (a code
  /// plugin's own dependencies) keep their entries; `pub get` resolves what
  /// is new and drops what is unused. Path and git packages are pinned by
  /// the pubspec itself (the project's copies, a plugin's `ref:`).
  ///
  /// Written when the host has no lock, when [force] (its pubspec changed),
  /// or when the lock holds an engine package at another version; a host
  /// that matches is left untouched. True when the lock was rewritten.
  Future<bool> _pinEngineLock(String hostDir, {required bool force}) async {
    final engineLock = _readLock(engineLockOf(hostDir));
    final pinned = _hostedEntries(engineLock);
    if (pinned.isEmpty) return false;
    final file = File(p.join(hostDir, 'pubspec.lock'));
    final existing = file.existsSync() ? (_readLock(file)?['packages']) : null;
    final current = existing is YamlMap ? existing : null;
    if (current != null && !force && movedFromEngineLock(hostDir).isEmpty) return false;
    final merged = <String, YamlMap>{
      if (current != null)
        for (final e in current.entries)
          if (e.value is YamlMap) '${e.key}': e.value as YamlMap,
      ...pinned,
    };
    final sdks = engineLock?['sdks'];
    final text = _lockText(merged, sdks is YamlMap ? sdks : null);
    if (file.existsSync() && file.readAsStringSync() == text) return false;
    await file.writeAsString(text, flush: true);
    return true;
  }

  static YamlMap? _readLock(File lock) {
    if (!lock.existsSync()) return null;
    try {
      final yaml = loadYaml(lock.readAsStringSync());
      return yaml is YamlMap ? yaml : null;
    } on YamlException {
      return null;
    }
  }

  static Map<String, YamlMap> _hostedEntries(YamlMap? lock) {
    final packages = lock?['packages'];
    if (packages is! YamlMap) return const {};
    return {
      for (final e in packages.entries)
        if (e.value case final YamlMap entry when entry['source'] == 'hosted') '${e.key}': entry,
    };
  }

  /// A `pubspec.lock` in pub's layout: packages and keys sorted, strings
  /// double-quoted.
  static String _lockText(Map<String, YamlMap> packages, YamlMap? sdks) {
    String scalar(Object? v) => v is String ? jsonEncode(v) : '$v';
    List<String> keys(YamlMap m) => [for (final k in m.keys) '$k']..sort();
    final b = StringBuffer()
      ..writeln("# Generated by Lumina Studio from the engine's pubspec.lock; pub rewrites it.")
      ..writeln('packages:');
    for (final name in packages.keys.toList()..sort()) {
      final entry = packages[name]!;
      b.writeln('  $name:');
      for (final key in keys(entry)) {
        final value = entry[key];
        if (value is YamlMap) {
          b.writeln('    $key:');
          for (final k in keys(value)) {
            b.writeln('      $k: ${scalar(value[k])}');
          }
        } else {
          b.writeln('    $key: ${scalar(value)}');
        }
      }
    }
    if (sdks != null) {
      b.writeln('sdks:');
      for (final k in keys(sdks)) {
        b.writeln('  $k: ${scalar(sdks[k])}');
      }
    }
    return b.toString();
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

    void addOverridesFrom(File file, String baseDir) {
      if (!file.existsSync()) return;
      try {
        final yaml = loadYaml(file.readAsStringSync());
        final deps = yaml is YamlMap ? yaml['dependency_overrides'] : null;
        if (deps is! YamlMap) return;
        for (final entry in deps.entries) {
          final name = '${entry.key}';
          if (overrides.containsKey(name)) continue;
          if (plugins.any((p) => p.name == name)) continue;
          final value = entry.value;
          if (value is YamlMap && value['path'] != null) {
            final target = p.normalize(p.join(baseDir, value['path'].toString()));
            if (Directory(target).existsSync()) {
              overrides[name] = _slash(p.absolute(target));
            }
          }
        }
      } on YamlException {
        // Ignore malformed yaml.
      }
    }

    addOverridesFrom(File(p.join(workspaceRoot, 'pubspec_overrides.yaml')), workspaceRoot);
    for (final plugin in plugins) {
      addOverridesFrom(File(p.join(plugin.pluginDir.path, 'pubspec_overrides.yaml')), plugin.pluginDir.path);
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
        final dir = _slash(p.absolute(plugin.pluginDir.path));
        b.writeln("    path: '$dir'");
        // Also an override: a plugin that depends on another enabled plugin
        // (from git, as published) takes the folder the host compiles.
        overrides[plugin.name] = dir;
      }
    }
    b
      ..writeln()
      ..writeln('dependency_overrides:');
    for (final name in overrides.keys.toList()..sort()) {
      final target = overrides[name]!;
      final formatted = target.contains('/') || target.contains(r'\') || target.contains(':')
          ? "'$target'"
          : target;
      b
        ..writeln('  $name:')
        ..writeln('    path: $formatted');
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
      processes: kPluginProcesses,
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
