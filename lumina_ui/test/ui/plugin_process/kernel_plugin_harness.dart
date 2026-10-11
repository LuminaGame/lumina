import 'dart:async';
import 'dart:io';

import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show EngineLoggerService, LuminaPluginDescriptor, PluginOrigin, PluginRepository;
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/core/services/crash_reporter.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/kernel_plugin_preparer.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_dialog_queue.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/host_editor_mcp.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:path/path.dart' as p;

import 'fixtures/kernel_sample_plugin.dart';
import 'plugin_process_harness.dart';

export 'fixtures/kernel_sample_plugin.dart';

/// A real extension registry, crash reporter, kernel preparer (its cache in
/// a temp folder, the test SDK's `dart`) and process manager without
/// compiled plugin processes: kernel plugins only.
class KernelPluginHarness {
  KernelPluginHarness._(this.root, this.registry, this.crashReporter, this.mcpTools, this.kernels, this.dialogs);

  final Directory root;
  final PluginExtensionRegistry registry;
  final CrashReporter crashReporter;
  final McpToolRegistry mcpTools;
  final KernelPluginPreparer kernels;
  final PluginDialogQueue dialogs;
  late final PluginProcessManager manager;

  Directory get pluginsDir => Directory(p.join(root.path, 'plugins'));
  Directory get cacheDir => Directory(p.join(root.path, 'plugin_kernels'));

  static Future<KernelPluginHarness> create() async {
    final root = await Directory.systemTemp.createTemp('lumina_kernel_plugin_');
    final tools = McpToolRegistry();
    final registry = PluginExtensionRegistry(logger: EngineLoggerService())
      ..attachMcp(() => HostEditorMcp(tools))
      ..attachStorage(dataRoot: () => Directory(p.join(root.path, 'data')), projectDir: () => p.join(root.path, 'project'))
      ..attachProjectInfo(() => EditorProjectInfo(name: 'Fixture', dir: p.join(root.path, 'project')));
    final reporter = CrashReporter(dataDir: Directory(p.join(root.path, 'lumina_data')));
    final kernels = KernelPluginPreparer(dartExecutable: sdkDart, cacheRoot: Directory(p.join(root.path, 'plugin_kernels')));
    final dialogs = PluginDialogQueue();
    final h = KernelPluginHarness._(root, registry, reporter, tools, kernels, dialogs);
    h.manager = PluginProcessManager(
      host: registry,
      processes: const {},
      timings: kFastTimings,
      crashReporter: () => reporter,
      kernels: kernels,
      dialogs: dialogs,
    );
    registry.attachProcesses(h.manager);
    return h;
  }

  /// The kernel sample plugin written into [pluginsDir] and read back as
  /// the plugin scan reads it.
  Future<LuminaPluginDescriptor> sample({String? sdkStamp, bool compile = true, String? entrySource, String version = '1.0.0'}) async {
    final dir = await writeKernelSamplePlugin(pluginsDir,
        sdkStamp: sdkStamp, compile: compile, entrySource: entrySource, version: version);
    return PluginRepository(roots: []).loadInternal(File(p.join(dir.path, '$kKernelSampleName.lmplugin')), PluginOrigin.user);
  }

  Future<void> dispose() async {
    await manager.shutdownAll();
    await crashReporter.detachLog();
    for (var i = 0; i < 10; i++) {
      try {
        await root.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
  }
}
