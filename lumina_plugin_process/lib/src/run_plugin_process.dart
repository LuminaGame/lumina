import 'dart:async';
import 'dart:io';

import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';

import 'package:lumina_editor_api/src/plugin_storage.dart';
import 'package:lumina_editor_api/src/plugin_crash_reporter.dart';
import 'package:lumina_editor_api/src/process/plugin_process.dart';
import 'package:lumina_editor_api/src/process/process_context.dart';
import 'package:lumina_editor_api/src/process/process_dispatch.dart';

/// The exit codes [runPluginProcessMain] completes with.
abstract final class PluginProcessExitCodes {
  /// `core.shutdown` was answered.
  static const int ok = 0;

  /// The editor closed the connection (or went away) without a shutdown.
  static const int connectionLost = 1;

  /// The editor's port could not be reached.
  static const int connectFailed = 2;

  /// The editor refused the hello (token or protocol version).
  static const int refused = 3;

  /// The plugin's `register` threw, or the editor refused its contributions.
  static const int registerFailed = 4;
}

/// The `main` of a plugin process: connects to the editor named by
/// [launch], says hello with its token, runs [process]'s
/// [LuminaPluginProcess.register] against a [PluginProcessContext] that
/// speaks the protocol, sends the contributions, then serves the editor's
/// requests until `core.shutdown` or the connection closes. Completes with
/// the process's exit code (0 after a shutdown, non-zero when the editor
/// went away or the handshake was refused, see [PluginProcessExitCodes]);
/// the caller exits with it.
Future<int> runPluginProcessMain(PluginProcessLaunch launch, LuminaPluginProcess process) async {
  final Socket socket;
  try {
    socket = await Socket.connect(InternetAddress.loopbackIPv4, launch.port, timeout: const Duration(seconds: 10));
  } on SocketException catch (e) {
    stderr.writeln('${launch.pluginName}: cannot reach the editor on port ${launch.port}: ${e.message}');
    return PluginProcessExitCodes.connectFailed;
  }
  socket.setOption(SocketOption.tcpNoDelay, true);
  try {
    return await servePluginProcess(
      input: socket,
      output: socket,
      pluginName: launch.pluginName,
      token: launch.token,
      process: process,
    );
  } finally {
    socket.destroy();
  }
}

/// [runPluginProcessMain] over an established byte stream pair (a socket
/// the caller connected, or an in-memory pipe): the handshake, registration
/// and request loop. The protocol connection is made inside the guarded zone
/// the plugin's code runs in, so an uncaught asynchronous error of a handler
/// is written to the editor's log instead of ending the process. Completes
/// with a [PluginProcessExitCodes] value; [output] is closed when it
/// completes.
Future<int> servePluginProcess({
  required Stream<List<int>> input,
  required StreamSink<List<int>> output,
  required String pluginName,
  required String token,
  required LuminaPluginProcess process,
}) {
  late final PluginConnection connection;
  final exit = Completer<int>();
  ConnectedPluginProcessContext? context;
  PluginCrashReportHandler? installedCrashHandler;
  var shuttingDown = false;

  void finish(int code) {
    if (!exit.isCompleted) exit.complete(code);
  }

  void report(Object error, StackTrace stack) {
    stderr.writeln('$pluginName: uncaught error: $error\n$stack');
    if (!connection.isClosed) {
      connection.notify(PluginMethods.log, {'level': 'error', 'message': 'uncaught error: $error\n$stack'});
    }
  }

  runZonedGuarded(() async {
    connection = PluginConnection(
      input: input,
      output: output,
      onProtocolError: (e, s) => stderr.writeln('$pluginName: protocol error: $e'),
    );
    connection.done.then((_) => finish(shuttingDown ? PluginProcessExitCodes.ok : PluginProcessExitCodes.connectionLost));

    final Map<String, Object?> hello;
    try {
      final r = await connection.request(PluginMethods.hello, {
        'v': kPluginProtocolVersion,
        'plugin': pluginName,
        'token': token,
        'pid': pid,
      });
      hello = r is Map ? r.cast<String, Object?>() : const {};
      if (hello['v'] != kPluginProtocolVersion) {
        throw PluginRemoteError(
          code: PluginErrorCodes.unsupportedVersion,
          message: 'the editor speaks protocol ${hello['v']}, this process $kPluginProtocolVersion',
        );
      }
    } on PluginRemoteError catch (e) {
      stderr.writeln('$pluginName: the editor refused the handshake: ${e.code}: ${e.message}');
      finish(e.code == PluginErrorCodes.closed ? PluginProcessExitCodes.connectionLost : PluginProcessExitCodes.refused);
      await connection.close();
      return;
    }

    final p = hello['project'];
    final project = p is Map && p['dir'] is String
        ? EditorProjectInfo(name: p['name'] as String? ?? '', dir: p['dir'] as String)
        : null;
    final s = hello['settings'];
    final userDir = hello['userDir'] as String?;
    final projectDir = hello['projectDir'] as String?;
    final pluginDir = hello['pluginDir'] as String?;
    final ctx = context = ConnectedPluginProcessContext(
      connection: connection,
      pluginName: pluginName,
      project: project,
      settings: s is Map ? s.cast<String, Object?>() : const {},
      userDir: Directory(userDir ?? '${Directory.systemTemp.path}/lumina_plugin_$pluginName'),
      projectStoreDir: projectDir == null ? null : Directory(projectDir),
      pluginDir: pluginDir,
    );
    // In a plugin process nothing else listens: the plugin's own crash
    // reports (LuminaPluginCrashReporter.reportCrash) go to the editor log.
    // Under the in-process override the editor's handler stays in charge.
    if (!LuminaPluginCrashReporter.hasHandler) {
      installedCrashHandler = (error, stack, {required plugin, context}) {
        if (connection.isClosed) return;
        connection.notify(PluginMethods.log, {
          'level': 'error',
          'source': plugin,
          'message': 'crash report${context == null ? '' : ' (while $context)'}: $error${stack == null ? '' : '\n$stack'}',
        });
      };
      LuminaPluginCrashReporter.setHandler(installedCrashHandler);
    }
    installPluginProcessHandlers(ctx, process, onShutdown: () {
      shuttingDown = true;
      connection.close();
    });
    if (project != null) await ctx.level.refresh();

    try {
      await process.register(ctx);
      final registered = connection.request(PluginMethods.register, ctx.contributions().toJson());
      // Live state changes from now on follow the contributions on the wire.
      ctx.watchLiveState();
      await registered;
    } catch (e, st) {
      // A shutdown answered before the register reply arrived closed the
      // link on purpose: that is a clean exit, not a failed registration.
      if (shuttingDown) {
        finish(PluginProcessExitCodes.ok);
        return;
      }
      final message = e is PluginRemoteError ? e.message : '$e';
      stderr.writeln('$pluginName: registration failed: $message');
      if (!connection.isClosed) {
        connection.notify(PluginMethods.log, {'level': 'error', 'message': 'registration failed: $message\n$st'});
      }
      finish(e is PluginRemoteError && e.code == PluginErrorCodes.closed
          ? PluginProcessExitCodes.connectionLost
          : PluginProcessExitCodes.registerFailed);
      await connection.close();
      return;
    }
    if (project != null) {
      try {
        await process.onProjectOpened(project);
      } catch (e, st) {
        ctx.log('onProjectOpened failed: $e\n$st', level: 'error');
      }
    }
  }, report);

  return exit.future.whenComplete(() async {
    if (installedCrashHandler != null) LuminaPluginCrashReporter.setHandler(null);
    context?.dispose();
    await connection.close();
  });
}
