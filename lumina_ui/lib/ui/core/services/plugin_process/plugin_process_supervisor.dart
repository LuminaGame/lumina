import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show BuildContext, IconData, LucideIcons, Widget;

import '../crash_reporter.dart';
import 'lucide_icon_table.dart';
import 'plugin_process_host.dart';
import 'plugin_process_launcher.dart';
import 'plugin_supervisor_timings.dart';
import '../../widgets/plugin_process_view_panel.dart';

part 'supervisor_contributions.dart';
part 'supervisor_host_handlers.dart';

/// Runs one isolated plugin's process part and keeps it alive.
///
/// [start] binds a loopback [ServerSocket] on port 0, starts the process
/// with [launcher] (or, with the project's in-process override, runs
/// [inProcessRunner] inside the editor over the same loopback protocol),
/// accepts its connection, checks the `host.hello` version and token, and
/// registers the `host.register` contributions into the editor under the
/// plugin's name. While running it sends `core.ping` every
/// [PluginSupervisorTimings.pingInterval]; after
/// [PluginSupervisorTimings.missedPingsForHung] unanswered pings the process
/// is hung: its whole tree is killed and it restarts. A process that exits
/// on its own is crashed: a plugin crash report is filed (exit code, log
/// tail) and it restarts. Automatic restarts wait
/// [PluginSupervisorTimings.restartBackoff] (1, 2, 4 s) and stop after the
/// last one; [restart] (the user's) resets the count. Contributions of a
/// stopped plugin stay registered but unavailable, and come back on restart.
///
/// It is also the plugin's [PluginProcessChannel], the one its in-process
/// shell gets from `context.processChannel(pluginName)`.
class PluginProcessSupervisor implements PluginProcessChannel {
  PluginProcessSupervisor({
    required this.pluginName,
    required this.host,
    this.launcher = const PluginProcessLauncher(),
    this.timings = const PluginSupervisorTimings(),
    this.inProcessRunner,
    CrashReporter? Function()? crashReporter,
    this.logTailLines = 300,
  }) : _crashReporter = crashReporter ?? (() => CrashReporter.instance);

  @override
  final String pluginName;
  final PluginProcessHost host;
  final PluginProcessLauncher launcher;
  final PluginSupervisorTimings timings;

  /// Set when the project runs this plugin in the editor process
  /// (`.lmproject` `plugin_isolation: {"<name>": "in_process"}`): the same
  /// process part and protocol, without a child process. Takes effect on the
  /// next start.
  Future<int> Function(PluginProcessLaunch launch)? inProcessRunner;

  final CrashReporter? Function() _crashReporter;

  /// How many lines of the process's output and log [logTail] keeps.
  final int logTailLines;

  bool get runsInEditorProcess => inProcessRunner != null;

  final ValueNotifier<PluginProcessState> _state =
      ValueNotifier(const PluginProcessState(PluginProcessStatus.stopped, reason: 'not started'));

  @override
  ValueListenable<PluginProcessState> get state => _state;

  /// Why the plugin cannot be used now ("`<plugin>` stopped: `<reason>`"), or
  /// null while it is available.
  String? get unavailableReason {
    final s = _state.value;
    if (s.isAvailable) return null;
    final why = s.reason ?? s.status.name;
    return switch (s.status) {
      PluginProcessStatus.starting => '$pluginName is starting',
      _ => '$pluginName stopped: $why',
    };
  }

  /// The exit code of the last process run (null before one ended, or when
  /// the system gave none).
  int? get lastExitCode => _lastExitCode;
  int? _lastExitCode;

  /// How many times a process was started.
  int get startCount => _startCount;
  int _startCount = 0;

  final List<String> _log = [];

  /// The process's own output (stdout, stderr), its `host.log` lines and
  /// the supervisor's notes, newest last.
  List<String> get logTail => List.unmodifiable(_log);

  /// Counts the lines added to [logTail]; listen to it to follow the log.
  final ValueNotifier<int> logRevision = ValueNotifier(0);

  final StreamController<PluginProcessEvent> _events = StreamController.broadcast();
  final StreamController<PluginProgress> _progress = StreamController.broadcast();

  @override
  Stream<PluginProcessEvent> events([String? name]) =>
      name == null ? _events.stream : _events.stream.where((e) => e.name == name);

  @override
  Stream<PluginProgress> get progress => _progress.stream;

  _Run? _run;
  Timer? _restartTimer;
  int _restarts = 0;
  bool _disposed = false;
  int _txSeq = 0;

  /// The contributions of the last registration (kept while stopped).
  PluginContributions? get contributions => _contributions;
  PluginContributions? _contributions;

  final Map<String, ValueNotifier<PluginViewSpec>> _views = {};
  final Map<String, _SlotState> _slots = {};
  final Map<String, ValueNotifier<bool>> _checked = {};
  final Map<String, (bool, DateTime)> _canExecuteCache = {};

  /// The declarative view [viewId] as last sent by the process.
  ValueListenable<PluginViewSpec>? viewOf(String viewId) => _views[viewId];

  // ── Lifecycle ─────────────────────────────────────────────────────

  /// Starts a process run (nothing when one is running or the supervisor
  /// is disposed).
  Future<void> start() async {
    if (_disposed || _run != null) return;
    _restartTimer?.cancel();
    _restartTimer = null;
    _setState(PluginProcessState(PluginProcessStatus.starting, restarts: _restarts));
    final ServerSocket server;
    try {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    } catch (e) {
      _note('could not open a loopback port: $e', level: 'error');
      _setState(PluginProcessState(PluginProcessStatus.stopped, reason: 'could not open a loopback port: $e', restarts: _restarts));
      return;
    }
    if (_disposed) {
      await server.close();
      return;
    }
    final run = _Run(server, _newToken());
    _run = run;
    _startCount++;
    server.listen((socket) => _onSocket(run, socket), onError: (_) {});
    final launch = PluginProcessLaunch(
      pluginName: pluginName,
      port: server.port,
      token: run.token,
      projectDir: host.projectInfo?.dir,
    );
    run.startTimer = Timer(timings.startTimeout, () => _kill(run, PluginProcessStatus.hung, 'did not start within ${timings.startTimeout.inSeconds} s'));
    final runner = inProcessRunner;
    if (runner != null) {
      _note('running in the editor process');
      Future<int>.sync(() => runner(launch)).then(
        (code) => _onExit(run, code),
        onError: (Object e, StackTrace s) {
          _note('in-process run failed: $e', level: 'error');
          _onExit(run, null, reason: 'failed: $e');
        },
      );
      return;
    }
    try {
      final process = await launcher.start(launch);
      run.process = process;
      _note('started (pid ${process.pid})');
      run.outputs = [
        _pipe(process.stdout, 'stdout'),
        _pipe(process.stderr, 'stderr'),
      ];
      process.exitCode.then((code) => _onExit(run, code));
    } catch (e) {
      _note('could not start: $e', level: 'error');
      _onExit(run, null, reason: 'could not start: $e');
    }
  }

  /// Restarts the process now (the user's Restart): the automatic restart
  /// count starts again from zero.
  @override
  Future<void> restart() async {
    if (_disposed) return;
    _restartTimer?.cancel();
    _restartTimer = null;
    _restarts = 0;
    await _stopRun(graceful: true);
    await start();
  }

  /// Stops the process for good (plugin disabled, mode switch): graceful
  /// `core.shutdown`, then a kill after [PluginSupervisorTimings.shutdownTimeout].
  Future<void> stop({String reason = 'stopped'}) async {
    _restartTimer?.cancel();
    _restartTimer = null;
    await _stopRun(graceful: true);
    if (!_disposed) _setState(PluginProcessState(PluginProcessStatus.stopped, reason: reason, exitCode: _lastExitCode, restarts: _restarts));
  }

  /// `core.projectClosing`, bounded by [PluginSupervisorTimings.projectClosingTimeout].
  Future<void> projectClosing() async {
    final conn = _run?.connection;
    if (conn == null || !_state.value.isAvailable) return;
    try {
      await conn.request(PluginMethods.projectClosing, const {}, timings.projectClosingTimeout);
    } on PluginRemoteError catch (e) {
      _note('onProjectClosing: ${e.message}', level: 'warning');
    }
  }

  /// Tells the process a project opened (`core.projectOpened`).
  void projectOpened(EditorProjectInfo project) {
    final conn = _run?.connection;
    if (conn == null || !_state.value.isAvailable) return;
    unawaited(conn.request(PluginMethods.projectOpened, {'name': project.name, 'dir': project.dir}).catchError((Object e) {
      _note('onProjectOpened: $e', level: 'warning');
      return null;
    }));
  }

  /// Editor exit: stops the process (graceful, then killed) and releases
  /// everything. The state stays as it was for a moment, then the
  /// supervisor is gone.
  Future<void> shutdown() async {
    if (_disposed) return;
    await stop(reason: 'the editor closed');
    dispose();
  }

  /// Releases streams and notifiers; a running process is killed.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _restartTimer?.cancel();
    final run = _run;
    if (run != null) {
      run.expectedExit = true;
      unawaited(_terminate(run));
    }
    for (final v in _views.values) {
      v.dispose();
    }
    for (final s in _slots.values) {
      s.notifier.dispose();
    }
    _events.close();
    _progress.close();
    logRevision.dispose();
  }

  // ── Channel ───────────────────────────────────────────────────────

  @override
  Future<Object?> call(String method, [Map<String, Object?> args = const {}, Duration? timeout]) async {
    final conn = _available();
    return conn.request(PluginMethods.call, {'method': method, 'args': args}, timeout ?? timings.callTimeout);
  }

  PluginConnection _available() {
    final conn = _run?.connection;
    if (conn == null || conn.isClosed || !_state.value.isAvailable) {
      throw PluginRemoteError(code: PluginErrorCodes.unavailable, message: unavailableReason ?? '$pluginName is not running');
    }
    return conn;
  }

  /// A request to the process on behalf of the editor (commands, tools,
  /// importers): [PluginErrorCodes.unavailable] when it is not running.
  Future<Object?> _request(String method, Map<String, Object?> args, Duration timeout) async =>
      _available().request(method, args, timeout);

  /// Sends a declarative panel's event to the process (`core.viewEvent`).
  Future<void> sendViewEvent(PluginViewEvent event) => _sendViewEvent(event);

  /// The pid the running plugin process reported in its hello (the
  /// editor's own pid for the in-process override).
  int? get reportedPid => _run?.reportedPid;

  /// The loopback port of the current run (null when none runs).
  int? get port => _run?.server.port;

  // ── Internals ─────────────────────────────────────────────────────

  void _setState(PluginProcessState next) {
    if (_disposed || _state.value == next) return;
    _state.value = next;
    _refreshSlots();
    host.processStateChanged(pluginName);
  }

  void _note(String message, {String level = 'info'}) {
    _appendLog('[supervisor] $message');
    if (level != 'info') host.logPlugin(pluginName, 'Plugin process: $message', level: level);
  }

  void _appendLog(String line) {
    _log.add(line);
    if (_log.length > logTailLines) _log.removeRange(0, _log.length - logTailLines);
    if (!_disposed) logRevision.value++;
  }

  StreamSubscription<String> _pipe(Stream<List<int>> bytes, String name) => bytes
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter())
      .listen((line) => _appendLog('[$name] $line'), onError: (_) {});

  void _onSocket(_Run run, Socket socket) {
    if (!identical(run, _run) || run.connection != null || run.exited) {
      socket.destroy();
      return;
    }
    late final PluginConnection conn;
    conn = PluginConnection(
      input: socket,
      output: socket,
      defaultTimeout: timings.callTimeout,
      onProtocolError: (e, _) => _note('protocol error: $e', level: 'warning'),
    );
    conn.onRequest(PluginMethods.hello, (args) => _hello(run, conn, args));
    unawaited(conn.done.then((_) => _onConnectionClosed(run, conn)));
  }

  Map<String, Object?> _hello(_Run run, PluginConnection conn, Map<String, Object?> args) {
    if (args['v'] != kPluginProtocolVersion) {
      Timer(const Duration(milliseconds: 200), conn.close);
      _note('refused a hello of protocol version ${args['v']} (this editor speaks $kPluginProtocolVersion)', level: 'error');
      throw PluginRemoteError(
        code: PluginErrorCodes.unsupportedVersion,
        message: 'protocol version ${args['v']} is not supported; the editor speaks $kPluginProtocolVersion',
      );
    }
    if (args['token'] != run.token || args['plugin'] != pluginName || run.connection != null) {
      Timer(const Duration(milliseconds: 200), conn.close);
      _note('refused a hello with a wrong token or plugin name', level: 'warning');
      throw const PluginRemoteError(code: PluginErrorCodes.unauthorized, message: 'wrong token or plugin name');
    }
    run.connection = conn;
    run.reportedPid = args['pid'] as int?;
    _bindHostHandlers(run, conn);
    final project = host.projectInfo;
    final storage = host.storageFor(pluginName);
    return {
      'v': kPluginProtocolVersion,
      'project': project == null ? null : {'name': project.name, 'dir': project.dir},
      'settings': host.settingsFor(pluginName).value,
      'userDir': storage.userDir.path,
      'projectDir': storage.projectDir?.path,
    };
  }

  void _registered(_Run run, PluginContributions contributions) {
    if (!identical(run, _run) || run.exited) return;
    run.startTimer?.cancel();
    _contributions = contributions;
    _applyContributions(contributions);
    _setState(PluginProcessState(
      runsInEditorProcess ? PluginProcessStatus.inProcess : PluginProcessStatus.running,
      restarts: _restarts,
      pid: run.process?.pid,
    ));
    _note('registered ${_describe(contributions)}');
    run.stableTimer = Timer(timings.stableAfter, () {
      if (!identical(run, _run) || _restarts == 0) return;
      _restarts = 0;
      _setState(PluginProcessState(_state.value.status, restarts: 0, pid: run.process?.pid));
    });
    _watchEditor(run);
    if (!runsInEditorProcess) unawaited(_pingLoop(run));
  }

  static String _describe(PluginContributions c) {
    final parts = [
      if (c.menuItems.isNotEmpty) '${c.menuItems.length} menu item(s)',
      if (c.slotButtons.isNotEmpty) '${c.slotButtons.length} slot button(s)',
      if (c.mcpTools.isNotEmpty) '${c.mcpTools.length} MCP tool(s)',
      if (c.importers.isNotEmpty) '${c.importers.length} importer(s)',
      if (c.consoleCommands.isNotEmpty) '${c.consoleCommands.length} console command(s)',
      if (c.panels.isNotEmpty) '${c.panels.length} panel(s)',
    ];
    return parts.isEmpty ? 'no contributions' : parts.join(', ');
  }

  Future<void> _pingLoop(_Run run) async {
    var missed = 0;
    while (identical(run, _run) && !run.exited && !_disposed) {
      final conn = run.connection;
      if (conn == null || conn.isClosed) return;
      final sw = Stopwatch()..start();
      try {
        await conn.request(PluginMethods.ping, const {}, timings.pingInterval);
        missed = 0;
        final rest = timings.pingInterval - sw.elapsed;
        if (rest > Duration.zero) await Future<void>.delayed(rest);
      } on PluginRemoteError catch (e) {
        if (e.code == PluginErrorCodes.closed) return;
        missed++;
        _note('missed health check $missed of ${timings.missedPingsForHung}');
        if (missed >= timings.missedPingsForHung) {
          await _kill(run, PluginProcessStatus.hung, 'not responding');
          return;
        }
      }
    }
  }

  /// Kills a hung (or never-starting) run, then restarts with back-off.
  Future<void> _kill(_Run run, PluginProcessStatus status, String reason) async {
    if (!identical(run, _run) || run.exited) return;
    run.expectedExit = true;
    _note('$reason: killing the process', level: 'warning');
    _setState(PluginProcessState(status, reason: reason, restarts: _restarts, pid: run.process?.pid));
    await _terminate(run);
    _afterFailure(status, reason, _lastExitCode);
  }

  /// Ends [run] now: its process tree is killed (or, in process, its
  /// connection closed), and waits for the exit.
  Future<void> _terminate(_Run run) async {
    final process = run.process;
    if (process != null) {
      await killProcessTree(process);
    } else {
      await run.connection?.close();
    }
    await run.exit.future.timeout(const Duration(seconds: 10), onTimeout: () {
      _onExit(run, null, reason: 'did not exit after being killed');
      return null;
    });
  }

  Future<void> _stopRun({required bool graceful}) async {
    final run = _run;
    if (run == null) return;
    run.expectedExit = true;
    final conn = run.connection;
    if (graceful && conn != null && !conn.isClosed) {
      try {
        await conn.request(PluginMethods.shutdown, const {}, timings.shutdownTimeout);
      } on PluginRemoteError catch (e) {
        _note('shutdown: ${e.message}');
      }
      final exited = await run.exit.future.then((_) => true).timeout(timings.shutdownTimeout, onTimeout: () => false);
      if (exited) return;
      _note('did not exit within ${timings.shutdownTimeout.inSeconds} s of shutdown: killing it', level: 'warning');
    }
    await _terminate(run);
  }

  void _onConnectionClosed(_Run run, PluginConnection conn) {
    if (!identical(run.connection, conn) || run.exited) return;
    _endTransactions(run);
    // The process closed its end but lives on: it gets the shutdown grace,
    // then it is killed (its exit decides crashed or not).
    if (run.process != null && !run.expectedExit) {
      Timer(timings.shutdownTimeout, () {
        if (!run.exited) unawaited(killProcessTree(run.process!));
      });
    }
  }

  void _onExit(_Run run, int? code, {String? reason}) {
    if (run.exited) return;
    run.exited = true;
    run.startTimer?.cancel();
    run.stableTimer?.cancel();
    run.levelDebounce?.cancel();
    run.unwatch?.call();
    _endTransactions(run);
    unawaited(run.server.close());
    unawaited(run.connection?.close());
    if (!run.exit.isCompleted) run.exit.complete(code);
    if (!identical(run, _run)) return;
    _run = null;
    _lastExitCode = code;
    if (_disposed) return;
    if (run.expectedExit) {
      _note('exited${code == null ? '' : ' with code $code'}');
      return;
    }
    final why = reason ?? exitReason(code);
    _note('the process $why', level: 'error');
    // Output may still be draining; the report takes what has arrived.
    _crashReporter()?.recordPluginCrash(plugin: pluginName, reason: why, exitCode: code, logTail: List.of(_log));
    _afterFailure(PluginProcessStatus.crashed, why, code);
  }

  void _afterFailure(PluginProcessStatus status, String reason, int? code) {
    if (_disposed) return;
    if (_restarts < timings.maxRestarts) {
      final delay = timings.restartBackoff[_restarts];
      _setState(PluginProcessState(status, reason: reason, exitCode: code, restarts: _restarts));
      _note('restarting in ${delay.inMilliseconds} ms (attempt ${_restarts + 1} of ${timings.maxRestarts})');
      _restartTimer = Timer(delay, () {
        _restartTimer = null;
        _restarts++;
        unawaited(start());
      });
    } else {
      _setState(PluginProcessState(PluginProcessStatus.stopped,
          reason: '$reason; gave up after $_restarts restarts', exitCode: code, restarts: _restarts));
      _note('gave up after $_restarts automatic restarts: use Restart', level: 'error');
    }
  }

  /// "exited with code N", with what `runPluginProcessMain`'s own exit
  /// codes ([PluginProcessExitCodes]) mean.
  static String exitReason(int? code) {
    if (code == null) return 'exited';
    final meaning = switch (code) {
      PluginProcessExitCodes.connectionLost => 'lost the connection to the editor',
      PluginProcessExitCodes.connectFailed => 'could not connect to the editor',
      PluginProcessExitCodes.refused => 'the editor refused its handshake',
      PluginProcessExitCodes.registerFailed => 'its register() threw',
      _ => null,
    };
    return meaning == null || code == 0 ? 'exited with code $code' : 'exited with code $code ($meaning)';
  }

  static String _newToken() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}

/// One process run: its port, process (or in-process run), connection and
/// open transactions.
class _Run {
  _Run(this.server, this.token);

  final ServerSocket server;
  final String token;
  Process? process;

  /// The pid the process said hello with (the program itself; the started
  /// one may be a launcher or shell in front of it).
  int? reportedPid;
  PluginConnection? connection;
  List<StreamSubscription<String>> outputs = const [];
  final Completer<int?> exit = Completer<int?>();
  bool exited = false;

  /// Stopped on purpose (restart, shutdown, hung): no crash report.
  bool expectedExit = false;
  Timer? startTimer;
  Timer? stableTimer;
  Timer? levelDebounce;
  void Function()? unwatch;
  final List<_Transaction> transactions = [];
}
