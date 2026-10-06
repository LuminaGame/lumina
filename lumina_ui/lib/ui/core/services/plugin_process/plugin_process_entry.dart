import 'dart:io';

import 'package:lumina_editor_api/lumina_editor_api.dart';

/// The exit code of a plugin process started with arguments it cannot use
/// (an unknown plugin name, an incomplete launch): `EX_USAGE`.
const int kPluginProcessUsageExit = 64;

/// The plugin-process mode of the editor executable: when [args] carry
/// `--lumina-plugin-process <name>` ([PluginProcessLaunch.parse]), runs the
/// process part `processes[name]` with `runPluginProcessMain` and returns
/// its exit code; returns null for a normal editor start. An unknown name
/// or incomplete arguments return [kPluginProcessUsageExit] with a message
/// on [stderrSink]. No window, crash session or plugin registry is involved.
Future<int?> runPluginProcessFromArgs(
  List<String> args,
  Map<String, LuminaPluginProcess Function()> processes, {
  StringSink? stderrSink,
  Future<int> Function(PluginProcessLaunch launch, LuminaPluginProcess process) run = runPluginProcessMain,
}) async {
  final err = stderrSink ?? stderr;
  final PluginProcessLaunch? launch;
  try {
    launch = PluginProcessLaunch.parse(args);
  } on FormatException catch (e) {
    err.writeln('Lumina plugin process: ${e.message}');
    return kPluginProcessUsageExit;
  }
  if (launch == null) return null;
  final factory = processes[launch.pluginName];
  if (factory == null) {
    final known = processes.keys.toList()..sort();
    err.writeln('Lumina plugin process: this editor has no process part for plugin "${launch.pluginName}" '
        '(known: ${known.isEmpty ? 'none' : known.join(', ')})');
    return kPluginProcessUsageExit;
  }
  return run(launch, factory());
}
