import 'dart:io';

import 'package:lumina_core/lumina_core.dart' show LuminaDataDir, LuminaWorkspace, PluginOrigin, PluginScanRoot;
import 'package:path/path.dart' as p;

import 'package:lumina_ui/ui/core/host/editor_host.dart' show LuminaEditorHost;

/// The per-user plugin install directory the editor scans with the
/// [PluginOrigin.user] origin and the Marketplace installs
/// plugin listings into: `<data>/plugins`, beside the rest of the per-user
/// data in [LuminaDataDir] (`~/.local/share/lumina` on Linux,
/// `%LOCALAPPDATA%\Lumina` on Windows).
///
/// Resolved in this order:
/// 1. [override], the in-process redirect a test sets to a temp directory;
/// 2. the `LUMINA_USER_PLUGIN_DIR` environment variable;
/// 3. `<data>/plugins`.
abstract final class UserPluginDir {
  static const String environmentVariable = 'LUMINA_USER_PLUGIN_DIR';

  /// In-process redirect, ahead of [environmentVariable].
  static Directory? override;

  static Directory resolve({Map<String, String>? environment}) {
    final redirected = override;
    if (redirected != null) return redirected;
    final env = environment ?? Platform.environment;
    final fromEnv = env[environmentVariable];
    if (fromEnv != null && fromEnv.isNotEmpty) return Directory(fromEnv);
    return Directory(p.join(LuminaDataDir.resolve(environment: env).path, 'plugins'));
  }
}

/// Where plugins keep their per-user data, one folder per
/// plugin: [override], else `LUMINA_PLUGIN_DATA_DIR`, else
/// `<data>/plugin_data` (beside the user plugin dir).
abstract final class PluginDataDir {
  static const String environmentVariable = 'LUMINA_PLUGIN_DATA_DIR';

  /// In-process redirect, ahead of [environmentVariable].
  static Directory? override;

  static Directory resolve({Map<String, String>? environment}) {
    final redirected = override;
    if (redirected != null) return redirected;
    final env = environment ?? Platform.environment;
    final fromEnv = env[environmentVariable];
    if (fromEnv != null && fromEnv.isNotEmpty) return Directory(fromEnv);
    return Directory(p.join(LuminaDataDir.resolve(environment: env).path, 'plugin_data'));
  }
}

/// Where the editor looks for plugins:
/// * the built-ins: the plugin packages the engine workspace resolved
///   ([LuminaWorkspace.pluginPackageDirs] of `<engineRoot>`: the plugins
///   repository's packages, pinned as git dependencies and fetched into the
///   pub cache, or their local checkout through `pubspec_overrides.yaml`),
///   plus an engine `plugins/` folder when there is one (`LUMINA_ENGINE_ROOT`,
///   else `<engineRoot>/plugins`) — never relative to the working directory,
///   which a project editor does not share with the engine;
/// * the project's `plugins/`;
/// * the per-user [UserPluginDir].
/// The launcher's project editor resolver scans the same roots as the editor.
List<PluginScanRoot> editorPluginScanRoots(String projectDir) {
  final engineRoot = LuminaEditorHost.engineRoot;
  final enginePlugins = Platform.environment['LUMINA_ENGINE_ROOT'] ?? p.join(engineRoot, 'plugins');
  return [
    PluginScanRoot.packages(
      dir: Directory(engineRoot),
      packageDirs: [for (final d in LuminaWorkspace.pluginPackageDirs(engineRoot)) Directory(d)],
      origin: PluginOrigin.engine,
    ),
    PluginScanRoot(dir: Directory(enginePlugins), origin: PluginOrigin.engine),
    // Normalised: a project path joined with `/` would give every project
    // plugin a mixed-separator folder (shown, and handed to its process).
    PluginScanRoot(dir: Directory(p.normalize(p.join(projectDir, 'plugins'))), origin: PluginOrigin.project),
    // <data>/plugins, where the Marketplace installs plugin
    // listings too.
    PluginScanRoot(dir: UserPluginDir.resolve(), origin: PluginOrigin.user),
  ];
}
