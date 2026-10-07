import 'package:flutter/foundation.dart';
import 'package:lumina_plugin_process/lumina_plugin_process.dart';

import 'package:lumina_editor_api/src/process/observable_adapters.dart';

/// The in-process shell's line to its plugin process
/// (`LuminaEditorContext.processChannel`): the Flutter face of a
/// [PluginProcessLink], whose [state] is a [ValueListenable] for widgets.
///
/// Calls fail with a [PluginRemoteError] when the process is not running
/// ([PluginErrorCodes.unavailable]), does not answer in time
/// ([PluginErrorCodes.timeout]) or its handler throws. The editor wraps the
/// shell's panels and tabs in a guard that shows the state and a Restart
/// button while [state] is not available, so a shell only handles errors of
/// its own calls.
abstract class PluginProcessChannel {
  String get pluginName;

  ValueListenable<PluginProcessState> get state;

  /// Calls the handler the process registered for [method]. [timeout]
  /// defaults to 30 s; long jobs answer early and report progress instead.
  Future<Object?> call(String method, [Map<String, Object?> args = const {}, Duration? timeout]);

  /// Events the process emits; [name] filters.
  Stream<PluginProcessEvent> events([String? name]);

  /// Progress reports of the process's tasks.
  Stream<PluginProgress> get progress;

  /// Restarts the process (manual: resets the automatic restart count).
  Future<void> restart();

  /// A channel for a context with no editor or no process behind it (tests,
  /// an in-process plugin, a bare registration context): [state] is
  /// [PluginProcessStatus.disabled] and every call fails with
  /// [PluginErrorCodes.unavailable].
  factory PluginProcessChannel.detached(String pluginName) =>
      PluginProcessChannel.ofLink(PluginProcessLink.detached(pluginName));

  /// [link] (the pure-Dart line, e.g. `LoopbackHost.link`) as a channel; the
  /// same link always gives the same channel.
  factory PluginProcessChannel.ofLink(PluginProcessLink link) => _channels[link] ??= _LinkChannel(link);
}

/// A Flutter [PluginProcessChannel] as a pure [PluginProcessLink], for code
/// that serves both (the state is seen through `asObservable()`).
extension PluginProcessChannelAsLink on PluginProcessChannel {
  PluginProcessLink asLink() {
    final self = this;
    return self is _LinkChannel ? self.link : _links[this] ??= _ChannelLink(this);
  }
}

final Expando<PluginProcessChannel> _channels = Expando('PluginProcessChannel.ofLink');
final Expando<PluginProcessLink> _links = Expando('PluginProcessChannel.asLink');

class _LinkChannel implements PluginProcessChannel {
  _LinkChannel(this.link);

  final PluginProcessLink link;

  @override
  String get pluginName => link.pluginName;

  @override
  late final ValueListenable<PluginProcessState> state = link.state.asValueListenable();

  @override
  Future<Object?> call(String method, [Map<String, Object?> args = const {}, Duration? timeout]) =>
      link.call(method, args, timeout);

  @override
  Stream<PluginProcessEvent> events([String? name]) => link.events(name);

  @override
  Stream<PluginProgress> get progress => link.progress;

  @override
  Future<void> restart() => link.restart();
}

class _ChannelLink implements PluginProcessLink {
  _ChannelLink(this.channel);

  final PluginProcessChannel channel;

  @override
  String get pluginName => channel.pluginName;

  @override
  late final Observable<PluginProcessState> state = channel.state.asObservable();

  @override
  Future<Object?> call(String method, [Map<String, Object?> args = const {}, Duration? timeout]) =>
      channel.call(method, args, timeout);

  @override
  Stream<PluginProcessEvent> events([String? name]) => channel.events(name);

  @override
  Stream<PluginProgress> get progress => channel.progress;

  @override
  Future<void> restart() => channel.restart();
}
