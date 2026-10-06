/// Test helpers for plugin authors: [LoopbackHost] plays the editor's side
/// of a plugin process link over a real loopback socket, so a plugin's
/// `LuminaPluginProcess` can be tested with `runPluginProcessMain` and its UI
/// shell with [LoopbackHost.channel].
library;

export 'testing/loopback_host.dart';
