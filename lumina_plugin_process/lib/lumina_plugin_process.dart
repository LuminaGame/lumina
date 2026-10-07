/// The part of a Lumina Studio plugin that runs in its own process, in pure
/// Dart.
///
/// - The process-side API: [LuminaPluginProcess], [PluginProcessContext] and
///   what a process registers (commands, slot buttons, declarative panels,
///   importers, MCP tools, console commands).
/// - Its runtime: [runPluginProcessMain] (connect, handshake, register,
///   serve) and [servePluginProcess] over any byte stream pair.
/// - The editor data it reads and writes: the open level
///   ([PluginLevelAccess], [EditorActorSnapshot], [EditorActorSpec]),
///   [PluginStorage], [EditorProjectInfo] and the MCP tool types.
/// - The editor side's line to a process ([PluginProcessLink]) and its state.
/// - The wire protocol (`package:lumina_plugin_protocol`) and the pure change
///   notification types of `lumina_core` ([Observable], [ObservableValue],
///   [ChangeSignal], [ChangeEmitter]).
///
/// No Flutter, `dart:ui` or FFI anywhere in its import graph
/// (`test/architecture/pure_dart_test.dart`): a plugin process written
/// against this library runs with `dart run`. `lumina_editor_api` re-exports
/// all of it, with the Flutter adapters (`asValueListenable()`,
/// `asObservable()`, `pluginIconOf`, `PluginProcessChannel`). The loopback
/// test host is `package:lumina_plugin_process/testing.dart`.
library;

export 'package:lumina_core/lumina_core.dart' show ChangeEmitter, ChangeSignal, Observable, ObservableValue;
export 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';

export 'package:lumina_plugin_process/src/editor_level.dart';
export 'package:lumina_plugin_process/src/level_json.dart';
export 'package:lumina_plugin_process/src/level_proxy.dart';
export 'package:lumina_plugin_process/src/mcp/editor_mcp.dart';
export 'package:lumina_plugin_process/src/mcp/mcp_types.dart';
export 'package:lumina_plugin_process/src/plugin_crash_reporter.dart';
export 'package:lumina_plugin_process/src/plugin_process.dart';
export 'package:lumina_plugin_process/src/plugin_process_link.dart';
export 'package:lumina_plugin_process/src/plugin_storage.dart';
export 'package:lumina_plugin_process/src/process_context.dart';
export 'package:lumina_plugin_process/src/process_dispatch.dart';
export 'package:lumina_plugin_process/src/run_plugin_process.dart';
