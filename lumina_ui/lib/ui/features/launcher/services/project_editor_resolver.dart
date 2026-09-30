import 'dart:convert';
import 'dart:io';

import 'package:lumina/lumina.dart';
import 'package:path/path.dart' as p;

import '../../../core/host/editor_host.dart';
import '../../../core/services/user_plugin_dir.dart';

/// What the launcher does with a project on Open.
sealed class ProjectEditorDecision {
  const ProjectEditorDecision();
}

/// The stock editor opens it: per-project editors are off (Editor
/// Preferences) and the project has no code plugins.
class OpenInPlace extends ProjectEditorDecision {
  const OpenInPlace();
}

/// The project's editor is built and current: exec it.
class ExecCached extends ProjectEditorDecision {
  final EditorBuildEntry entry;
  const ExecCached(this.entry);
}

/// The host exists but its fingerprint is not cached (stale or never built
/// here): build it behind the splash.
class NeedsBuild extends ProjectEditorDecision {
  /// "editor source changed (lumina_ui)", "plugin lumina_plugin_miniai changed", ….
  final String reason;
  final List<LuminaPluginDescriptor> plugins;
  const NeedsBuild(this.reason, this.plugins);
  List<String> get pluginNames => [for (final d in plugins) d.name];
}

/// Code plugins are enabled but the host is absent (an older project, a
/// fresh clone, another OS): ask before building.
class MissingBinary extends ProjectEditorDecision {
  final String reason;
  final List<LuminaPluginDescriptor> plugins;
  const MissingBinary(this.reason, this.plugins);
  List<String> get pluginNames => [for (final d in plugins) d.name];
}

/// Decides how a project opens: in place, in its cached project editor, or
/// after a build. Scans the same plugin roots as the editor.
class ProjectEditorResolver {
  final String engineRoot;
  final EditorBuildCache cache;
  final EditorHostGeneratorService generator;

  /// `release` (default) or `debug` (Editor Preferences → Project Editor Builds).
  final String mode;
  final String platform;
  final Future<FlutterToolInfo> Function() flutterInfo;
  final List<PluginScanRoot> Function(String projectDir) scanRoots;

  /// Every project opens in its own project editor, code plugins
  /// or not (Editor Preferences › Project Editor Builds; default on). Off,
  /// a plugin-less project opens in the stock editor.
  final bool everyProject;

  /// The running engine's identity (default: read from [engineRoot]).
  final Future<EngineIdentity> Function() currentEngine;

  ProjectEditorResolver({
    String? engineRoot,
    EditorBuildCache? cache,
    EditorHostGeneratorService? generator,
    this.mode = 'release',
    String? platform,
    Future<FlutterToolInfo> Function()? flutterInfo,
    List<PluginScanRoot> Function(String projectDir)? scanRoots,
    this.everyProject = true,
    Future<EngineIdentity> Function()? currentEngine,
  })  : engineRoot = engineRoot ?? LuminaEditorHost.engineRoot,
        currentEngine = currentEngine ?? (() => EngineIdentity.of(engineRoot ?? LuminaEditorHost.engineRoot)),
        cache = cache ?? EditorBuildCache(),
        generator = generator ?? EditorHostGeneratorService(engineRoot: engineRoot ?? LuminaEditorHost.engineRoot),
        platform = platform ?? EditorHostInputs.currentPlatform(),
        flutterInfo = flutterInfo ?? FlutterToolInfo.probe,
        scanRoots = scanRoots ?? editorPluginScanRoots;

  /// The project's enabled plugins that contribute editor code, as found on
  /// the plugin roots (an enabled plugin that is not installed is skipped).
  Future<List<LuminaPluginDescriptor>> enabledCodePlugins(String projectDir) async {
    final name = EditorHostGeneratorService.projectNameIn(projectDir);
    if (name == null) return const [];
    final project = await ProjectRepository().loadProject(p.join(projectDir, '$name.lmproject'));
    final enabled = project?.enabledPlugins ?? const <String>[];
    if (enabled.isEmpty) return const [];
    final scan = await PluginRepository(roots: scanRoots(projectDir)).scanAll();
    return EditorHostGeneratorService.editorCodePlugins([
      for (final d in scan.plugins)
        if (enabled.contains(d.name)) d,
    ]);
  }

  /// The inputs of the project's host build (see `fingerprint`).
  Future<EditorHostInputs> inputsFor(String projectDir, List<LuminaPluginDescriptor> plugins) async {
    final flutter = await flutterInfo();
    final hostDir = EditorHostGeneratorService.hostDirOf(projectDir);
    return EditorHostInputs(
      hostDir: hostDir,
      // The editor compiles the project's copy of the source.
      engineRoot: hostDir,
      repos: EditorSourceVendorService.copiedRepos(hostDir),
      pluginDirs: {for (final d in plugins) d.name: d.pluginDir.path},
      flutterVersion: flutter.version,
      flutterRevision: flutter.revision,
      platform: platform,
      mode: mode,
    );
  }

  Future<ProjectEditorDecision> resolve(String projectDir, {bool rebuild = false}) async {
    final plugins = await enabledCodePlugins(projectDir);
    final names = [for (final d in plugins) d.name];
    if (plugins.isEmpty && !everyProject) return const OpenInPlace();
    final hostDir = Directory(EditorHostGeneratorService.hostDirOf(projectDir));
    if (!hostDir.existsSync() && plugins.isEmpty) {
      // A new, older or cloned project with no code plugins: nothing to ask.
      await generator.generate(projectDir, const []);
      return NeedsBuild("first build of this project's editor", plugins);
    }
    if (!hostDir.existsSync()) {
      return MissingBinary('No editor host for ${names.join(', ')} in .lumina/editor on this machine', plugins);
    }
    // Brings the host in line with enabled_plugins and the engine's runner;
    // a no-op (byte-identical) when nothing changed. A host in the old
    // layout is migrated to build from a copy in the project.
    final oldLayout = EditorHostGeneratorService.isOldLayout(hostDir.path);
    await generator.generate(projectDir, plugins);
    if (oldLayout) return NeedsBuild('editor source copied into the project', plugins);
    if (!EditorSourceVendorService(engineRoot: engineRoot).isVendored(hostDir.path)) {
      return NeedsBuild('the editor source is not in the project yet (about 650 MB will be copied)', plugins);
    }
    if (!File(p.join(hostDir.path, 'pubspec.lock')).existsSync()) {
      return NeedsBuild('not built on this machine yet', plugins);
    }
    final components = await fingerprintComponents(await inputsFor(projectDir, plugins));
    final hash = fingerprintOf(components);
    final hit = cache.lookup(hash);
    if (hit != null && !rebuild) {
      await cache.touch(hash);
      return ExecCached(hit);
    }
    if (rebuild && hit != null) return NeedsBuild('rebuild requested', plugins);
    return NeedsBuild(staleReason(hostDir.path, components), plugins);
  }

  /// Whether the project's copy of the engine source comes from another
  /// engine than the one at [engineRoot] (default: this resolver's, the
  /// running Studio's), whose identity is [current] (default:
  /// [currentEngine] for this resolver's root, else read from [engineRoot]):
  /// null when there is no copy or it is current. See
  /// [EditorSourceVendorService.engineUpdate].
  Future<EditorEngineUpdate?> engineUpdate(String projectDir, {EngineIdentity? current, String? engineRoot}) async {
    final root = engineRoot ?? this.engineRoot;
    final name = EditorHostGeneratorService.projectNameIn(projectDir);
    String? projectEngineVersion;
    if (name != null) {
      try {
        final json = jsonDecode(File(p.join(projectDir, '$name.lmproject')).readAsStringSync());
        if (json is Map && json['engine_version'] is String) projectEngineVersion = json['engine_version'] as String;
      } on FormatException {
        // An unreadable manifest names no version.
      } on FileSystemException {
        // Same.
      }
    }
    return EditorSourceVendorService(engineRoot: root).engineUpdate(
      EditorHostGeneratorService.hostDirOf(projectDir),
      current: current ?? (engineRoot == null ? await currentEngine() : await EngineIdentity.of(root)),
      projectEngineVersion: projectEngineVersion,
    );
  }

  /// What changed since the host's last build, from its stamp.
  static String staleReason(String hostDir, Map<String, String> current) {
    final stamp = readStamp(hostDir);
    final inputs = stamp?['inputs'];
    if (inputs is! Map) return 'not built on this machine yet';
    final reasons = diffInputs(inputs.map((k, v) => MapEntry('$k', '$v')), current);
    return reasons.isEmpty ? 'the build cache no longer holds it' : reasons.join(', ');
  }

  static Map<String, dynamic>? readStamp(String hostDir) {
    final f = File(p.join(hostDir, EditorHostGeneratorService.stampFileName));
    if (!f.existsSync()) return null;
    try {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  /// A project editor's self-check: the reasons its compiled-in
  /// [compiledFingerprint] no longer matches the project's current inputs
  /// (empty when current, or when this is not a built project editor).
  Future<List<String>> staleSelfCheck(String projectDir, String compiledFingerprint) async {
    if (compiledFingerprint.isEmpty) return const [];
    final hostDir = EditorHostGeneratorService.hostDirOf(projectDir);
    final stamp = readStamp(hostDir);
    final plugins = await enabledCodePlugins(projectDir);
    final current = await fingerprintComponents(await inputsFor(projectDir, plugins));
    if (fingerprintOf(current) == compiledFingerprint) return const [];
    final inputs = stamp?['hash'] == compiledFingerprint ? stamp!['inputs'] : null;
    if (inputs is! Map) return const ['its build inputs changed'];
    final reasons = diffInputs(inputs.map((k, v) => MapEntry('$k', '$v')), current);
    return reasons.isEmpty ? const ['its build inputs changed'] : reasons;
  }
}
