import 'package:lumina_core/lumina_core.dart' show Observable, ObservableValue;
import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';
import 'package:meta/meta.dart';

/// Where a plugin process is in its life, as the editor sees it.
enum PluginProcessStatus {
  /// The plugin runs in the editor process (no process to supervise).
  inProcess,

  /// Started, handshake or registration not finished yet.
  starting,

  /// Answering.
  running,

  /// Missed three health pings in a row; being restarted.
  hung,

  /// Exited on its own (non-zero exit code, native crash, or killed).
  crashed,

  /// Gave up after the restart attempts, or the user stopped it; Restart
  /// brings it back.
  stopped,

  /// The plugin is disabled for this project.
  disabled,
}

/// A snapshot of a plugin process's state.
@immutable
class PluginProcessState {
  const PluginProcessState(
    this.status, {
    this.reason,
    this.exitCode,
    this.restarts = 0,
    this.pid,
  });

  final PluginProcessStatus status;

  /// Why it is not running ("not responding", "exited with code 3", …).
  final String? reason;
  final int? exitCode;

  /// Automatic restarts since the last manual start.
  final int restarts;
  final int? pid;

  /// Calls can be made.
  bool get isAvailable => status == PluginProcessStatus.running || status == PluginProcessStatus.inProcess;

  @override
  bool operator ==(Object other) =>
      other is PluginProcessState &&
      other.status == status &&
      other.reason == reason &&
      other.exitCode == exitCode &&
      other.restarts == restarts &&
      other.pid == pid;

  @override
  int get hashCode => Object.hash(status, reason, exitCode, restarts, pid);

  @override
  String toString() => 'PluginProcessState(${status.name}${reason == null ? '' : ': $reason'})';
}

/// An event the plugin process emitted (`PluginProcessContext.emit`).
@immutable
class PluginProcessEvent {
  const PluginProcessEvent(this.name, this.data);
  final String name;
  final Object? data;
}

/// A progress report of a plugin process task.
@immutable
class PluginProgress {
  const PluginProgress({
    required this.task,
    required this.step,
    this.done,
    this.total,
    this.message,
    this.finished = false,
  });

  final String task;
  final String step;
  final int? done;
  final int? total;
  final String? message;
  final bool finished;

  /// 0..1 when [done] and [total] are known.
  double? get fraction => (done != null && total != null && total! > 0) ? (done! / total!).clamp(0.0, 1.0) : null;

  static PluginProgress fromJson(Map<String, Object?> json) => PluginProgress(
        task: json['task'] as String? ?? '',
        step: json['step'] as String? ?? '',
        done: json['done'] as int?,
        total: json['total'] as int?,
        message: json['message'] as String?,
        finished: json['finished'] == true,
      );
}

/// The editor side's line to a plugin process, in pure Dart: what a UI
/// shell calls (`PluginProcessChannel` in `lumina_editor_api` is the same
/// line with a Flutter `ValueListenable` state; `PluginProcessChannel.ofLink`
/// wraps one of these). The loopback test host's `LoopbackHost.link` is one.
///
/// Calls fail with a [PluginRemoteError] when the process is not running
/// ([PluginErrorCodes.unavailable]), does not answer in time
/// ([PluginErrorCodes.timeout]) or its handler throws.
abstract class PluginProcessLink {
  const PluginProcessLink();

  String get pluginName;

  Observable<PluginProcessState> get state;

  /// Calls the handler the process registered for [method]. [timeout]
  /// defaults to 30 s; long jobs answer early and report progress instead.
  Future<Object?> call(String method, [Map<String, Object?> args = const {}, Duration? timeout]);

  /// Events the process emits; [name] filters.
  Stream<PluginProcessEvent> events([String? name]);

  /// Progress reports of the process's tasks.
  Stream<PluginProgress> get progress;

  /// Restarts the process (manual: resets the automatic restart count).
  Future<void> restart();

  /// A link with no process behind it: [state] is
  /// [PluginProcessStatus.disabled] and every call fails with
  /// [PluginErrorCodes.unavailable].
  factory PluginProcessLink.detached(String pluginName) = _DetachedLink;
}

class _DetachedLink implements PluginProcessLink {
  _DetachedLink(this.pluginName);

  @override
  final String pluginName;

  @override
  final Observable<PluginProcessState> state =
      ObservableValue(const PluginProcessState(PluginProcessStatus.disabled, reason: 'no plugin process'));

  @override
  Future<Object?> call(String method, [Map<String, Object?> args = const {}, Duration? timeout]) =>
      Future.error(PluginRemoteError(code: PluginErrorCodes.unavailable, message: '$pluginName has no plugin process'));

  @override
  Stream<PluginProcessEvent> events([String? name]) => const Stream.empty();

  @override
  Stream<PluginProgress> get progress => const Stream.empty();

  @override
  Future<void> restart() async {}
}
