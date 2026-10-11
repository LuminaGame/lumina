import 'dart:io';

import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_launcher.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:path/path.dart' as p;

import '../plugin_process/plugin_process_harness.dart' show dartExecutable;

/// The OpenXR plugin (LuminaGame/lumina_plugin_openxr): its name, its OpenXR
/// panel's id and the panel's asset path inside the plugin.
const String kOpenxrPlugin = 'lumina_plugin_openxr';
const String kOpenxrPanelAsset = 'content/Editor/EPW_OpenXR.lmas';
const String kOpenxrPanelId = '$kOpenxrPlugin/$kOpenxrPanelAsset';

/// The OpenXR plugin's checkout: `LUMINA_OPENXR_DIR`, else `openxr/` next
/// to this workspace's repositories; null when it is not there (or has no
/// `pub get` yet, so its process cannot run).
Directory? openxrCheckout() {
  final env = Platform.environment['LUMINA_OPENXR_DIR'];
  final dir = Directory(env != null && env.isNotEmpty ? env : p.join(p.dirname(LuminaWorkspace.root), 'openxr'));
  bool has(String rel) => File(p.join(dir.path, rel)).existsSync();
  final ok = has('$kOpenxrPlugin.lmplugin') &&
      has(kOpenxrPanelAsset) &&
      has(p.join('bin', 'openxr_process.dart')) &&
      has(p.join('.dart_tool', 'package_config.json'));
  return ok ? dir : null;
}

/// Why OpenXR tests skip on this machine, or null when they run.
String? openxrSkipReason() => openxrCheckout() == null
    ? 'the OpenXR plugin checkout (LUMINA_OPENXR_DIR or ../openxr, with content/Editor/EPW_OpenXR.lmas and pub get) is missing'
    : null;

/// Never constructed: the editor runs the plugin's real process
/// (`bin/openxr_process.dart`, the simulated OpenXR runtime) as a child.
class OpenxrProcessPart extends LuminaPluginProcess {
  @override
  String get pluginName => kOpenxrPlugin;

  @override
  void register(PluginProcessContext context) {}
}

/// Installs [checkout] as a user plugin: a link in the user plugin folder
/// (`UserPluginDir.override`), as a developer's plugin checkout is. Returns
/// the link, which the caller deletes before its temp folder (never
/// recursing into the checkout).
Link installOpenxrUserPlugin(Directory checkout) {
  final root = UserPluginDir.override!..createSync(recursive: true);
  return Link(p.join(root.path, kOpenxrPlugin))..createSync(checkout.absolute.path);
}

/// The editor's process manager for the OpenXR plugin, attached to [vm]:
/// the plugin's real process on the Dart VM.
PluginProcessManager attachOpenxrProcess(EditorViewModel vm, Directory checkout,
    {PluginSupervisorTimings timings = const PluginSupervisorTimings(
      pingInterval: Duration(milliseconds: 500),
      restartBackoff: [],
      startTimeout: Duration(seconds: 90),
      callTimeout: Duration(seconds: 10),
      shutdownTimeout: Duration(seconds: 3),
    )}) {
  final dart = dartExecutable();
  final manager = PluginProcessManager(
    host: vm.extensionRegistry,
    processes: {kOpenxrPlugin: OpenxrProcessPart.new},
    launcher: PluginProcessLauncher(
      executable: dart,
      leadingArgs: [p.join(checkout.path, 'bin', 'openxr_process.dart')],
      workingDirectory: checkout.path,
      runInShell: Platform.isWindows && dart == 'dart',
    ),
    timings: timings,
  );
  vm.extensionRegistry.attachProcesses(manager);
  return manager;
}
