/// The wire protocol between Lumina Studio (the host) and a plugin running in
/// its own process (the plugin process).
///
/// - [PluginFrameCodec]: 4-byte big-endian length + UTF-8 JSON object frames.
/// - [PluginMessage]: requests, responses and notifications.
/// - [PluginConnection]: a bidirectional request/response + notification
///   endpoint with per-call timeouts, used on both sides.
/// - [PluginProcessLaunch]: the command-line contract the host starts a
///   plugin process with.
/// - [PluginContributions] and its parts: everything an isolated plugin
///   registers, as data.
/// - [PluginViewSpec]: declarative panels the host renders.
///
/// Pure Dart (no Flutter): a test fixture or a plugin process can use it
/// with `dart run`.
library;

export 'package:lumina_plugin_protocol/src/contributions.dart';
export 'package:lumina_plugin_protocol/src/frame_codec.dart';
export 'package:lumina_plugin_protocol/src/launch.dart';
export 'package:lumina_plugin_protocol/src/messages.dart';
export 'package:lumina_plugin_protocol/src/plugin_connection.dart';
export 'package:lumina_plugin_protocol/src/view_spec.dart';
