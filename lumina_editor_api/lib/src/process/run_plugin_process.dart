import 'dart:async';

import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';

import 'plugin_process.dart';

/// The `main` of a plugin process: connects to the editor named by
/// [launch], says hello with its token, runs [process]'s
/// [LuminaPluginProcess.register] against a [PluginProcessContext] that
/// speaks the protocol, sends the contributions, then serves the editor's
/// requests until `core.shutdown` or the connection closes. Completes with
/// the process's exit code (0 after a shutdown, non-zero when the editor
/// went away or the handshake was refused); the caller exits with it.
Future<int> runPluginProcessMain(PluginProcessLaunch launch, LuminaPluginProcess process) {
  throw UnimplementedError('runPluginProcessMain is being built on this branch');
}
