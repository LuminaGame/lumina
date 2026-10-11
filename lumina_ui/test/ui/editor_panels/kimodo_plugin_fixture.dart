import 'dart:io';

import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/kernel_plugin_preparer.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:path/path.dart' as p;

import '../plugin_process/fixtures/kernel_sample_plugin.dart' show sdkDart;

/// The Kimodo plugin (LuminaGame/lumina_plugin_kimodo) as a kernel plugin:
/// its name, its editor panels' asset paths and ids.
const String kKimodoPlugin = 'lumina_plugin_kimodo';
const String kKimodoEditorAsset = 'content/Editor/EPW_KimodoEditor.lmas';
const String kKimodoMappingAsset = 'content/Editor/EPW_KimodoMapping.lmas';
const String kKimodoWeightsAsset = 'content/Editor/EPW_KimodoWeights.lmas';
const String kKimodoSettingsAsset = 'content/Editor/EPW_KimodoSettings.lmas';
String kimodoPanelId(String asset) => '$kKimodoPlugin/$asset';

/// The Quinn mannequin of the shared test assets as a project skeletal mesh.
const String kQuinnMesh = 'contents/meshes/skeletal/SKM_Quinn_Simple.lmas';

/// The Kimodo plugin's checkout: `LUMINA_KIMODO_DIR`, else `kimodo/` next to
/// this workspace's repositories; null unless it is the kernel plugin (a
/// `process_entry`, its `EPW_` panels) with its packages resolved.
Directory? kimodoCheckout() {
  final env = Platform.environment['LUMINA_KIMODO_DIR'];
  final dir = Directory(env != null && env.isNotEmpty ? env : p.join(p.dirname(LuminaWorkspace.root), 'kimodo'));
  bool has(String rel) => File(p.join(dir.path, rel)).existsSync();
  final manifest = File(p.join(dir.path, '$kKimodoPlugin.lmplugin'));
  final kernel = manifest.existsSync() && manifest.readAsStringSync().contains('process_entry');
  final ok = kernel &&
      has(kKimodoEditorAsset) &&
      has(p.join('bin', 'kimodo_process.dart')) &&
      has(p.join('.dart_tool', 'package_config.json'));
  return ok ? dir : null;
}

/// Why Kimodo kernel tests skip on this machine, or null when they run.
String? kimodoSkipReason() => kimodoCheckout() == null
    ? 'the Kimodo kernel plugin checkout (LUMINA_KIMODO_DIR or ../kimodo, with bin/kimodo_process.dart, '
        'content/Editor/EPW_KimodoEditor.lmas and pub get) is missing'
    : null;

/// Installs [checkout] as a user plugin (a link in the user plugin folder),
/// as a developer's checkout is. The caller deletes the link before its temp
/// folder, never recursing into the checkout.
Link installKimodoUserPlugin(Directory checkout) {
  final root = UserPluginDir.override!..createSync(recursive: true);
  return Link(p.join(root.path, kKimodoPlugin))..createSync(checkout.absolute.path);
}

/// Writes the Quinn mannequin into [projectDir]; false when the test asset
/// is missing.
bool importQuinn(Directory projectDir) {
  final glb = File(p.join(LuminaWorkspace.root, 'test-assets', 'mannequin', 'exports', 'SKM_Quinn_Simple.glb'));
  if (!glb.existsSync()) return false;
  final dir = Directory(p.join(projectDir.path, 'contents', 'meshes', 'skeletal'))..createSync(recursive: true);
  final bytes = glb.readAsBytesSync();
  File(p.join(dir.path, 'SKM_Quinn_Simple.entity.glb')).writeAsBytesSync(bytes);
  File(p.join(projectDir.path, kQuinnMesh)).writeAsBytesSync(LuminaAsset(
    assetId: 'quinn-mesh-id',
    name: 'SKM_Quinn_Simple',
    type: AssetType.filameshSk,
    rawPayload: bytes,
    metadata: const {'payload_format': 'glb'},
  ).toProtoBufferBytes());
  return true;
}

/// The editor's process manager for kernel plugins, attached to [vm]: the
/// kernel compiled with this test's Dart SDK (into [cacheRoot]) and run on
/// the Dart VM, as the editor does for a kernel plugin.
PluginProcessManager attachKernelProcesses(EditorViewModel vm, Directory cacheRoot) {
  final manager = PluginProcessManager(
    host: vm.extensionRegistry,
    processes: const {},
    kernels: KernelPluginPreparer(dartExecutable: sdkDart, cacheRoot: cacheRoot),
    timings: const PluginSupervisorTimings(
      pingInterval: Duration(milliseconds: 500),
      restartBackoff: [],
      startTimeout: Duration(seconds: 120),
      callTimeout: Duration(seconds: 20),
      shutdownTimeout: Duration(seconds: 5),
    ),
  );
  vm.extensionRegistry.attachProcesses(manager);
  return manager;
}

/// The Kimodo descriptor as the editor's plugin scan read it.
Future<LuminaPluginDescriptor> kimodoDescriptor(Link installed) => PluginRepository(roots: [])
    .loadInternal(File(p.join(installed.path, '$kKimodoPlugin.lmplugin')), PluginOrigin.user);
