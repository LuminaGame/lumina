/// Test helpers for plugin authors, in pure Dart: [LoopbackHost] plays the
/// editor's side of a plugin process link over a real loopback socket, so a
/// plugin's `LuminaPluginProcess` can be tested with `runPluginProcessMain`
/// (in the test's isolate or as a separate `dart` process) and a UI shell's
/// calls with [LoopbackHost.link]. Flutter tests import
/// `package:lumina_editor_api/testing.dart`, which re-exports this and adds
/// `host.channel`. [PluginProcessReach] lists what a plugin's process part
/// imports, for the plugin's architecture test.
library;

export 'package:lumina_plugin_process/src/testing/loopback_host.dart';
export 'package:lumina_plugin_process/src/testing/process_reach.dart';
