import 'dart:async';
import 'dart:io';

import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginProcessLaunch;

/// Starts the process of an isolated plugin.
///
/// The default starts this editor's own executable again
/// (`Platform.resolvedExecutable`) with [PluginProcessLaunch.toArgs]: in that
/// mode `runLuminaEditor` shows no window and runs the plugin's process part.
/// [executable] and [leadingArgs] replace it (a test runs a Dart script with
/// the `dart` executable); the launch arguments always come last. stdout and
/// stderr stay piped: the supervisor keeps them in the plugin's log.
class PluginProcessLauncher {
  const PluginProcessLauncher({
    this.executable,
    this.leadingArgs = const [],
    this.workingDirectory,
    this.environment,
    this.runInShell = false,
  });

  /// The program; null is this process's own executable.
  final String? executable;

  /// Arguments before the launch arguments (a script path, a mode).
  final List<String> leadingArgs;
  final String? workingDirectory;
  final Map<String, String>? environment;

  /// Needed on Windows for `.bat` programs (`dart`/`flutter` from the SDK's
  /// `bin/`); the supervisor kills the whole tree, so the shell's child goes
  /// too.
  final bool runInShell;

  /// The command line [start] runs for [launch].
  List<String> commandLine(PluginProcessLaunch launch) =>
      [executable ?? Platform.resolvedExecutable, ...leadingArgs, ...launch.toArgs()];

  Future<Process> start(PluginProcessLaunch launch) {
    final line = commandLine(launch);
    return Process.start(
      line.first,
      line.sublist(1),
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    );
  }
}

/// Kills [process] and every process it started (a shell's child, a
/// plugin's own child processes): `taskkill /T /F` on Windows, the
/// descendants found with `pgrep -P` then SIGKILL elsewhere.
Future<void> killProcessTree(Process process) async {
  final pid = process.pid;
  if (Platform.isWindows) {
    try {
      final r = await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
      if (r.exitCode == 0) return;
    } catch (_) {
      // taskkill missing: fall back to the process itself.
    }
    process.kill(ProcessSignal.sigkill);
    return;
  }
  final descendants = await _descendantsOf(pid);
  process.kill(ProcessSignal.sigkill);
  for (final child in descendants.reversed) {
    Process.killPid(child, ProcessSignal.sigkill);
  }
}

Future<List<int>> _descendantsOf(int pid) async {
  final out = <int>[];
  try {
    final r = await Process.run('pgrep', ['-P', '$pid']);
    for (final line in (r.stdout as String).split('\n')) {
      final child = int.tryParse(line.trim());
      if (child == null) continue;
      out
        ..add(child)
        ..addAll(await _descendantsOf(child));
    }
  } catch (_) {
    // No pgrep: only the process itself is killed.
  }
  return out;
}
