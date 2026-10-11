part of 'plugin_process_supervisor.dart';

/// A request timeout the connection itself never reaches; the supervisor
/// enforces the real one ([_pausingTimeout]).
const Duration _noTimeout = Duration(days: 365);

extension _Launch on PluginProcessSupervisor {
  /// Runs [PluginProcessSupervisor.prepareLaunch]: the state says what it
  /// does ("Preparing `<plugin>` for Dart `<x>`…"), the progress stream and the
  /// log get each stage. Null after a failure, which stops the plugin with
  /// the reason (no crash report, no automatic restart).
  Future<PluginProcessLauncher?> _prepare() async {
    _preparing = true;
    _preparationError = null;
    final refused = _vmRefusedLast;
    void progress(String line) {
      _note(line);
      if (!_disposed) {
        _setState(PluginProcessState(PluginProcessStatus.starting, reason: line, restarts: _restarts));
        if (!_progress.isClosed) _progress.add(PluginProgress(task: 'kernel', step: line));
      }
    }

    try {
      final launcher = await prepareLaunch!(refused, progress);
      _vmRefusedLast = false;
      if (!_progress.isClosed) _progress.add(const PluginProgress(task: 'kernel', step: 'ready', finished: true));
      return launcher;
    } catch (e) {
      final message = '$e';
      _preparationError = message;
      _note('could not be prepared: $message', level: 'error');
      if (!_progress.isClosed) _progress.add(PluginProgress(task: 'kernel', step: 'failed', message: message, finished: true));
      _setState(PluginProcessState(PluginProcessStatus.stopped,
          reason: 'could not be prepared: ${message.split('\n').first}', restarts: _restarts));
      return null;
    } finally {
      _preparing = false;
    }
  }

  /// The Dart VM refused [run]'s kernel (it was built by another SDK):
  /// starts again at once, recompiling, instead of counting a crash. Only
  /// once in a row; a recompiled kernel refused again is a crash.
  bool _kernelRefused(_Run run) {
    final refused = launchRefused;
    if (refused == null || _vmRefusedLast || !refused(run.stderr)) return false;
    _vmRefusedLast = true;
    _note('the Dart VM refused the kernel (built by another Dart SDK): recompiling it', level: 'warning');
    unawaited(start());
    return true;
  }

  /// [request] with [timeout] counted only while the plugin has no dialog
  /// open: the user decides how long a dialog takes.
  Future<T> _pausingTimeout<T>(Future<T> request, String method, Duration timeout) {
    final done = Completer<T>();
    var waited = Duration.zero;
    const tick = Duration(milliseconds: 50);
    final timer = Timer.periodic(tick, (t) {
      if (!dialogs.hasDialog(pluginName)) waited += tick;
      if (waited >= timeout && !done.isCompleted) {
        t.cancel();
        done.completeError(PluginRemoteError(
          code: PluginErrorCodes.timeout,
          message: '$method did not answer within ${timeout.inMilliseconds} ms',
        ));
      }
    });
    request.then((v) {
      timer.cancel();
      if (!done.isCompleted) done.complete(v);
    }, onError: (Object e, StackTrace s) {
      timer.cancel();
      if (!done.isCompleted) done.completeError(e, s);
    });
    return done.future;
  }
}
