import 'dart:async';

import 'package:lumina_editor_api/lumina_editor_api.dart';

import '../crash_reporter.dart';
import 'plugin_process_host.dart';
import 'plugin_process_launcher.dart';
import 'plugin_process_supervisor.dart';
import 'plugin_supervisor_timings.dart';

/// Runs a plugin's process part inside the editor (the in-process
/// override): the default is `runPluginProcessMain(launch, factory())`.
typedef InEditorPluginRunner = Future<int> Function(PluginProcessLaunch launch, LuminaPluginProcess Function() factory);

/// One [PluginProcessSupervisor] per isolated plugin of this editor
/// (`LuminaEditorHost.pluginProcesses`): starts them, answers each
/// plugin's channel, switches a plugin between its own process and the
/// editor process (the project's `plugin_isolation` override), and passes
/// the project lifecycle on.
class PluginProcessManager {
  PluginProcessManager({
    required this.host,
    required Map<String, LuminaPluginProcess Function()> processes,
    Set<String> Function()? inEditorProcess,
    this.launcher = const PluginProcessLauncher(),
    this.timings = const PluginSupervisorTimings(),
    InEditorPluginRunner? inEditorRunner,
    this.crashReporter,
  })  : _factories = Map.unmodifiable(processes),
        _inEditorProcess = inEditorProcess ?? (() => const {}),
        _inEditorRunner = inEditorRunner ?? ((launch, factory) => runPluginProcessMain(launch, factory()));

  final PluginProcessHost host;
  final Map<String, LuminaPluginProcess Function()> _factories;
  final Set<String> Function() _inEditorProcess;
  final PluginProcessLauncher launcher;
  final PluginSupervisorTimings timings;
  final InEditorPluginRunner _inEditorRunner;
  final CrashReporter? Function()? crashReporter;

  final Map<String, PluginProcessSupervisor> _supervisors = {};

  /// The isolated plugins this editor knows, by name.
  Iterable<String> get pluginNames => _factories.keys;

  bool isIsolated(String plugin) => _factories.containsKey(plugin);

  /// [plugin]'s supervisor (created on first use), or null when it has no
  /// process part.
  PluginProcessSupervisor? supervisorOf(String plugin) {
    final factory = _factories[plugin];
    if (factory == null) return null;
    return _supervisors.putIfAbsent(
      plugin,
      () => PluginProcessSupervisor(
        pluginName: plugin,
        host: host,
        launcher: launcher,
        timings: timings,
        crashReporter: crashReporter,
      )..inProcessRunner = _inEditorProcess().contains(plugin) ? _runnerFor(factory) : null,
    );
  }

  List<PluginProcessSupervisor> get supervisors => [for (final name in _factories.keys) supervisorOf(name)!];

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
