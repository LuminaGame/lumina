import 'dart:async';

import 'package:flutter/foundation.dart';

/// Where an [McpJob] is.
enum McpJobState { queued, running, succeeded, failed, cancelled }

/// One line of a job's log; [index] is stable for the job's lifetime, so an
/// agent pages with `get_job({since_log_index})`.
class McpJobLogLine {
  final int index;
  final DateTime at;
  final String level;
  final String source;
  final String message;
  const McpJobLogLine({required this.index, required this.at, required this.level, required this.source, required this.message});

  Map<String, Object?> toJson() => {'index': index, 'level': level, 'source': source, 'message': message};
}

/// Thrown by a job's `run` to end it as `failed` with a [result] (a build
/// whose pipeline failed still reports its per-step statuses).
class McpJobFailure implements Exception {
  final String message;
  final Object? result;
  const McpJobFailure(this.message, {this.result});

  @override
  String toString() => message;
}

/// A second job on an exclusive resource while one runs there.
class McpJobConflict implements Exception {
  final McpJob running;
  const McpJobConflict(this.running);

  String get message => '${running.id} (${running.title}) is still ${running.state.name} on "${running.exclusive}"; '
      'wait_job / cancel_job it first.';

  @override
  String toString() => message;
}

/// A long-running operation an MCP call started and returned at once:
/// a Build All, a Cook & Package, Play Standalone, a widget
/// library switch. The agent polls it (`get_job`), long-polls it
/// (`wait_job`, bounded) or cancels it (`cancel_job`); no MCP call ever
/// blocks for the whole operation.
class McpJob {
  McpJob._(this.id, this.kind, this.title, this.exclusive, this._cancel) : started = DateTime.now();

  final String id;
  final String kind;
  final String title;

  /// The resource key this job holds alone while it runs, or null.
  final String? exclusive;
  final void Function()? _cancel;

  McpJobState _state = McpJobState.queued;
  McpJobState get state => _state;

  /// 0..1, or null while unmeasurable.
  double? progress;

  /// What the job is doing now (`Running Validate Assets…`, `running`).
  String? stage;

  final DateTime started;
  DateTime? finished;
  Object? result;
  String? error;

  final List<McpJobLogLine> _log = [];
  List<McpJobLogLine> get log => List.unmodifiable(_log);
  int get nextLogIndex => _log.length;

  final Completer<void> _settled = Completer<void>();
  final Completer<void> _runDone = Completer<void>();
  bool _cancelCalled = false;

  /// Whether the job has left `queued` / `running`.
  bool get isDone => _state != McpJobState.queued && _state != McpJobState.running;

  /// Completes when the job leaves `running`.
  Future<void> get settled => _settled.future;

  /// Completes when the job's `run` has returned (after a cancel too).
  Future<void> get runDone => _runDone.future;

  /// Whether `cancel_job` was called.
  bool get cancelRequested => _cancelCalled;

  VoidCallback? _changed;

  void addLog(String message, {String level = 'info', String source = 'Job'}) {
    _log.add(McpJobLogLine(index: _log.length, at: DateTime.now(), level: level, source: source, message: message));
    _changed?.call();
  }

  void update({double? progress, String? stage, bool clearProgress = false}) {
    if (clearProgress) {
      this.progress = null;
    } else if (progress != null) {
      this.progress = progress;
    }
    if (stage != null) this.stage = stage;
    _changed?.call();
  }

  void _settle(McpJobState state) {
    if (isDone) return;
    _state = state;
    finished = DateTime.now();
    if (state == McpJobState.succeeded) progress = 1;
    if (!_settled.isCompleted) _settled.complete();
    _changed?.call();
  }

  Duration get elapsed => (finished ?? DateTime.now()).difference(started);

  /// The job as `list_jobs` shows it.
  Map<String, Object?> summary() => {
        'id': id,
        'kind': kind,
        'title': title,
        'state': state.name,
        'progress': progress,
        'stage': stage,
        'started': started.toIso8601String(),
        'finished': finished?.toIso8601String(),
        'elapsed_ms': elapsed.inMilliseconds,
        'exclusive': exclusive,
        'log_lines': _log.length,
      };

  /// The job as `get_job` shows it: [summary], result, error, log lines
  /// from [sinceLogIndex] (the last [tail] of them).
  Map<String, Object?> detail({int sinceLogIndex = 0, int tail = 100}) {
    final from = sinceLogIndex.clamp(0, _log.length);
    var lines = _log.sublist(from);
    if (lines.length > tail) lines = lines.sublist(lines.length - tail);
    return {
      ...summary(),
      'result': result,
      'error': error,
      'log': [for (final l in lines) l.toJson()],
      'next_log_index': _log.length,
    };
  }
}

/// The session's jobs: ids
/// `job_<n>`, the last [capacity] kept, one running job per exclusive key.
class McpJobRegistry extends ChangeNotifier {
  McpJobRegistry({this.capacity = 50});

  final int capacity;
  final List<McpJob> _jobs = [];
  int _next = 1;
  bool _disposed = false;

  List<McpJob> get jobs => List.unmodifiable(_jobs);

  McpJob? byId(String id) {
    for (final j in _jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  /// The job running on [exclusive], or null.
  McpJob? runningOn(String exclusive) {
    for (final j in _jobs) {
      if (j.exclusive == exclusive && !j.isDone) return j;
    }
    return null;
  }

  /// Starts [run] as a new job and returns it at once. [cancel] is what
  /// `cancel_job` calls (once). With [exclusive] set, a second job while one
  /// runs on the same key throws [McpJobConflict]. `run`'s value becomes the
  /// job's result (`succeeded`); an [McpJobFailure] or any other exception
  /// ends it `failed`.
  McpJob start(
    String kind, {
    required Future<Object?> Function(McpJob job) run,
    String? title,
    void Function()? cancel,
    String? exclusive,
  }) {
    if (exclusive != null) {
      final busy = runningOn(exclusive);
      if (busy != null) throw McpJobConflict(busy);
    }
    final job = McpJob._('job_${_next++}', kind, title ?? kind, exclusive, cancel);
    job._changed = _notify;
    _jobs.add(job);
    _evict();
    job._state = McpJobState.running;
    _notify();
    // Run on the next microtask so the starting call returns first.
    scheduleMicrotask(() async {
      try {
        final value = await run(job);
        job.result ??= value;
        job._settle(McpJobState.succeeded);
      } on McpJobFailure catch (e) {
        job.result ??= e.result;
        job.error ??= e.message;
        job._settle(McpJobState.failed);
      } catch (e) {
        job.error ??= '$e';
        job._settle(McpJobState.failed);
      } finally {
        if (!job._runDone.isCompleted) job._runDone.complete();
        _notify();
      }
    });
    return job;
  }

  /// Cancels [job]: its cancel callback runs once and it is `cancelled` at
  /// once. Returns false when it had already finished.
  bool cancel(McpJob job) {
    if (job.isDone) return false;
    if (!job._cancelCalled) {
      job._cancelCalled = true;
      job.addLog('Cancel requested', level: 'warning');
      try {
        job._cancel?.call();
      } catch (e) {
        job.addLog('Cancel raised: $e', level: 'error');
      }
    }
    job._settle(McpJobState.cancelled);
    return true;
  }

  /// Waits until [job] leaves `running`, at most [timeout]; returns whether
  /// it did.
  Future<bool> wait(McpJob job, Duration timeout) async {
    if (job.isDone) return true;
    try {
      await job.settled.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  void _evict() {
    while (_jobs.length > capacity) {
      final index = _jobs.indexWhere((j) => j.isDone);
      _jobs.removeAt(index < 0 ? 0 : index);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
