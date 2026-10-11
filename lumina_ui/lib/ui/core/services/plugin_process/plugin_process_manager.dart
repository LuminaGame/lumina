import 'dart:async';

import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaPluginDescriptor;

import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/services/crash_reporter.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/kernel_plugin_preparer.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_dialog_queue.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_host.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_launcher.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_supervisor.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';

/// Runs a plugin's process part inside the editor (the in-process
/// override): the default is `runPluginProcessMain(launch, factory())`.
typedef InEditorPluginRunner = Future<int> Function(PluginProcessLaunch launch, LuminaPluginProcess Function() factory);

/// One [PluginProcessSupervisor] per isolated plugin of this editor: the
/// compiled ones (`LuminaEditorHost.pluginProcesses`) and the kernel
/// plugins the plugin registry enables ([syncKernelPlugins], started and
/// stopped live, run on the Dart VM through [kernels]). Starts them,
/// answers each plugin's channel, switches a compiled plugin between its
/// own process and the editor process (the project's `plugin_isolation`
/// override), and passes the project lifecycle on.
class PluginProcessManager {
  PluginProcessManager({
    required this.host,
    required Map<String, LuminaPluginProcess Function()> processes,
    Set<String> Function()? inEditorProcess,
    this.launcher = const PluginProcessLauncher(),
    this.timings = const PluginSupervisorTimings(),
    InEditorPluginRunner? inEditorRunner,
    this.crashReporter,
    KernelPluginPreparer? kernels,
    PluginDialogQueue? dialogs,
  })  : kernels = kernels ?? KernelPluginPreparer(),
        dialogs = dialogs ?? PluginDialogQueue.shared,
        _factories = Map.unmodifiable(processes),
        _inEditorProcess = inEditorProcess ?? (() => const {}),
        _inEditorRunner = inEditorRunner ?? ((launch, factory) => runPluginProcessMain(launch, factory()));

  final PluginProcessHost host;
  final Map<String, LuminaPluginProcess Function()> _factories;
  final Set<String> Function() _inEditorProcess;
  final PluginProcessLauncher launcher;
  final PluginSupervisorTimings timings;
  final InEditorPluginRunner _inEditorRunner;
  final CrashReporter? Function()? crashReporter;

  /// Checks, recompiles and caches kernel plugins' kernels.
  final KernelPluginPreparer kernels;

  /// Where plugin processes' dialogs are shown.
  final PluginDialogQueue dialogs;

  final Map<String, PluginProcessSupervisor> _supervisors = {};
  final Map<String, LuminaPluginDescriptor> _kernelPlugins = {};

  /// The isolated plugins this editor knows, by name: compiled ones first.
  Iterable<String> get pluginNames =>
      [..._factories.keys, ..._kernelPlugins.keys.where((k) => !_factories.containsKey(k))];

  bool isIsolated(String plugin) => _factories.containsKey(plugin) || _kernelPlugins.containsKey(plugin);

  /// Whether [plugin] is an enabled kernel plugin (run on the Dart VM).
  bool isKernel(String plugin) => !_factories.containsKey(plugin) && _kernelPlugins.containsKey(plugin);

  /// The kernel plugins running (or meant to run) now, by name.
  Map<String, LuminaPluginDescriptor> get kernelPlugins => Map.unmodifiable(_kernelPlugins);

  /// [plugin]'s supervisor (created on first use), or null when it has no
  /// process part.
  PluginProcessSupervisor? supervisorOf(String plugin) {
    final factory = _factories[plugin];
    if (factory == null) {
      final kernel = _kernelPlugins[plugin];
      return kernel == null ? null : _supervisors.putIfAbsent(plugin, () => _kernelSupervisor(kernel));
    }
    return _supervisors.putIfAbsent(
      plugin,
      () => PluginProcessSupervisor(
        pluginName: plugin,
        host: host,
        launcher: launcher,
        timings: timings,
        crashReporter: crashReporter,
        dialogs: dialogs,
      )..inProcessRunner = _inEditorProcess().contains(plugin) ? _runnerFor(factory) : null,
    );
  }

  List<PluginProcessSupervisor> get supervisors => [for (final name in pluginNames) supervisorOf(name)!];

  PluginProcessSupervisor _kernelSupervisor(LuminaPluginDescriptor d) => PluginProcessSupervisor(
        pluginName: d.name,
        host: host,
        timings: timings,
        crashReporter: crashReporter,
        dialogs: dialogs,
        prepareLaunch: (vmRefused, progress) async {
          final prep = await kernels.prepare(d, vmRefused: vmRefused, onProgress: progress);
          return PluginProcessLauncher.kernel(prep.dart, prep.kernel, workingDirectory: d.pluginDir.path);
        },
        launchRefused: KernelPluginPreparer.vmRefusedKernel,
      );

  /// Brings the running kernel plugins in line with [enabled] (the plugin
  /// registry's enabled kernel plugins), live: a new one gets a supervisor
  /// and starts (when [start]); one no longer listed, or listed with
  /// another version or folder (updated, reinstalled), is shut down
  /// (graceful `core.shutdown`, then killed), its contributions, panels
  /// and MCP tools removed, and an updated one starts again. No editor
  /// restart either way.
  Future<void> syncKernelPlugins(Iterable<LuminaPluginDescriptor> enabled, {bool start = true}) async {
    final wanted = {
      for (final d in enabled)
        if (d.isKernelPlugin && !_factories.containsKey(d.name)) d.name: d,
    };
    final stops = <Future<void>>[];
    for (final name in _kernelPlugins.keys.toList()) {
      final now = wanted[name];
      final before = _kernelPlugins[name]!;
      if (now != null && now.version == before.version && now.pluginDir.path == before.pluginDir.path) continue;
      _kernelPlugins.remove(name);
      final s = _supervisors.remove(name);
      if (s != null) stops.add(_retire(s, now == null ? 'disabled' : 'updated'));
    }
    await Future.wait(stops);
    final added = <String>[];
    for (final d in wanted.values) {
      if (_kernelPlugins.containsKey(d.name)) continue;
      _kernelPlugins[d.name] = d;
      // The hello answer hands the process its folder.
      LuminaEditorHost.pluginDirs = {...LuminaEditorHost.pluginDirs, d.name: d.pluginDir.path};
      added.add(d.name);
    }
    if (start) await Future.wait([for (final name in added) supervisorOf(name)!.start()]);
  }

  Future<void> _retire(PluginProcessSupervisor s, String reason) async {
    await s.stop(reason: reason);
    host.removeProcessContributions(s.pluginName);
    dialogs.closeAllOf(s.pluginName);
    s.dispose();
    host.processStateChanged(s.pluginName);
  }

  Future<int> Function(PluginProcessLaunch) _runnerFor(LuminaPluginProcess Function() factory) =>
      (launch) => _inEditorRunner(launch, factory);

  /// Starts every plugin process (those of [only] when given).
  Future<void> startAll({Set<String>? only}) async {
    await Future.wait([
      for (final s in supervisors)
        if (only == null || only.contains(s.pluginName)) s.start(),
    ]);
  }

  /// Whether [plugin] runs inside the editor process now.
  bool runsInEditorProcess(String plugin) => supervisorOf(plugin)?.runsInEditorProcess ?? false;

  /// Moves [plugin] into the editor process ([inEditorProcess]) or back
  /// into its own, restarting it; its channel stays the same object.
  Future<void> setRunInEditorProcess(String plugin, bool inEditorProcess) async {
    if (isKernel(plugin)) return;
    final s = supervisorOf(plugin);
    if (s == null || s.runsInEditorProcess == inEditorProcess) return;
    s.inProcessRunner = inEditorProcess ? _runnerFor(_factories[plugin]!) : null;
    await s.restart();
  }

  /// `core.projectClosing` to every running plugin process, in parallel
  /// (each bounded).
  Future<void> projectClosing() => Future.wait([for (final s in _supervisors.values) s.projectClosing()]);

  /// Stops every plugin process (graceful `core.shutdown`, then killed) and
  /// releases the supervisors.
  Future<void> shutdownAll() async {
    final all = _supervisors.values.toList();
    await Future.wait([for (final s in all) s.shutdown()]);
  }
}
