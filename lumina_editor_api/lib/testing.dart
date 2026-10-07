/// Test helpers for plugin authors: [LoopbackHost] plays the editor's side
/// of a plugin process link over a real loopback socket, so a plugin's
/// `LuminaPluginProcess` can be tested with `runPluginProcessMain` and its UI
/// shell with [LoopbackHost.channel].
///
/// The host is the pure-Dart one of `package:lumina_plugin_process/testing.dart`
/// (re-exported here) with the Flutter face of its link added.
library;

import 'dart:io';

import 'package:lumina_plugin_process/lumina_plugin_process.dart';
import 'package:lumina_plugin_process/testing.dart' as pure;

import 'package:lumina_editor_api/src/process/plugin_process_channel.dart';

export 'package:lumina_plugin_process/testing.dart' hide LoopbackHost;

/// The pure loopback test host ([pure.LoopbackHost]) plus [channel], the
/// line a Flutter UI shell gets from the editor.
class LoopbackHost extends pure.LoopbackHost {
  LoopbackHost._(super.server, super.root, super.token, super.answerVersion, super.project) : super.bound();

  /// Binds a port and waits for one plugin process (see
  /// [pure.LoopbackHost.start]).
  static Future<LoopbackHost> start({
    String token = 'token-1',
    int answerVersion = kPluginProtocolVersion,
    bool withProject = true,
    Map<String, Object?> settings = const {'density': 3},
    String? pluginDir,
  }) =>
      pure.LoopbackHost.bind(
        (ServerSocket server, Directory root, String token, int answerVersion, EditorProjectInfo? project) =>
            LoopbackHost._(server, root, token, answerVersion, project),
        token: token,
        answerVersion: answerVersion,
        withProject: withProject,
        settings: settings,
        pluginDir: pluginDir,
      );

  /// A [PluginProcessChannel] over [link], as a UI shell gets from the
  /// editor: `call` goes to the process's `handle` handlers, `events` and
  /// `progress` carry its `emit` / `progress` reports. Its state is running
  /// while the link is open and crashed once it closes.
  late final PluginProcessChannel channel = PluginProcessChannel.ofLink(link);
}
