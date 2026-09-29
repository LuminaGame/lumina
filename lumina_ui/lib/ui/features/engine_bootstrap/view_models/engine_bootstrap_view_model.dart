import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart'
    show
        EngineBootstrap,
        EngineBootstrapCompleted,
        EngineBootstrapEvent,
        EngineBootstrapException,
        EngineBootstrapFailed,
        EngineBootstrapLog,
        EngineBootstrapPrerequisites,
        EngineBootstrapProgress,
        EngineBootstrapStep,
        EngineBootstrapStepDone,
        EngineCheckout,
        EnginePrerequisite;

/// Where a bootstrap step stands.
enum BootstrapStepStatus { pending, running, done, skipped, failed }

/// One row of the first-launch screen.
class BootstrapStepState {
  final BootstrapStepStatus status;

  /// 0–1, or null while unknown.
  final double? fraction;

  /// The latest progress message.
  final String message;

  const BootstrapStepState({this.status = BootstrapStepStatus.pending, this.fraction, this.message = ''});

  BootstrapStepState copyWith({BootstrapStepStatus? status, double? fraction, bool clearFraction = false, String? message}) =>
      BootstrapStepState(
        status: status ?? this.status,
        fraction: clearFraction ? null : (fraction ?? this.fraction),
        message: message ?? this.message,
      );
}

/// Drives an [EngineBootstrap] for the first-launch screen and the Engine
/// Source preferences: per-step state, the log, the error and Retry.
class EngineBootstrapViewModel extends ChangeNotifier {
  EngineBootstrapViewModel(this.bootstrap);

  final EngineBootstrap bootstrap;

  /// The most log lines kept.
  static const int maxLogLines = 4000;

  final Map<EngineBootstrapStep, BootstrapStepState> _steps = {
    for (final s in EngineBootstrapStep.values) s: const BootstrapStepState(),
  };
  final List<String> _log = [];
  List<EnginePrerequisite> _prerequisites = const [];
  EngineBootstrapException? _error;
  EngineCheckout? _checkout;
  bool _running = false;
  bool _disposed = false;
  Completer<EngineCheckout?>? _run;

  BootstrapStepState step(EngineBootstrapStep s) => _steps[s]!;
  List<String> get log => List.unmodifiable(_log);
  List<EnginePrerequisite> get prerequisites => _prerequisites;
  EngineBootstrapException? get error => _error;
  EngineCheckout? get checkout => _checkout;
  bool get running => _running;
  bool get failed => _error != null && !_running;
  bool get completed => _checkout != null && !_running;

  /// Required prerequisites that are missing (they stop the bootstrap).
  List<EnginePrerequisite> get missing =>
      _error?.missing.isNotEmpty == true ? _error!.missing : [for (final pr in _prerequisites) if (pr.required && !pr.found) pr];

  /// Optional prerequisites that are missing (reported only).
  List<EnginePrerequisite> get warnings => [for (final pr in _prerequisites) if (!pr.required && !pr.found) pr];

  /// The step that is running now, or the one that failed.
  EngineBootstrapStep? get currentStep {
    for (final s in EngineBootstrapStep.values) {
      final st = _steps[s]!.status;
      if (st == BootstrapStepStatus.running || st == BootstrapStepStatus.failed) return s;
    }
    return null;
  }

  /// Runs the bootstrap (a second call while it runs joins the first);
  /// [force] downloads the engine source again. Completes with the
  /// checkout, or null when it failed.
  Future<EngineCheckout?> start({bool force = false}) {
    final existing = _run;
    if (existing != null && !existing.isCompleted) return existing.future;
    final run = _run = Completer<EngineCheckout?>();
    _running = true;
    _error = null;
    _checkout = null;
    for (final s in EngineBootstrapStep.values) {
      _steps[s] = const BootstrapStepState();
    }
    _append(force ? 'Downloading engine ${bootstrap.version} again' : 'Preparing engine ${bootstrap.version}');
    _notify();
    bootstrap.run(force: force).listen(_onEvent, onDone: () {
      _running = false;
      _notify();
      if (!run.isCompleted) run.complete(_checkout);
    });
    return run.future;
  }

  /// Starts again after a failure.
  Future<EngineCheckout?> retry() => start();

  void _onEvent(EngineBootstrapEvent e) {
    switch (e) {
      case EngineBootstrapProgress(:final step, :final fraction, :final message):
        _steps[step] = _steps[step]!.copyWith(
            status: BootstrapStepStatus.running, fraction: fraction, clearFraction: fraction == null, message: message);
        if (fraction == null || fraction == 0 || fraction == 1) _append(message);
      case EngineBootstrapLog(:final line):
        _append(line);
      case EngineBootstrapStepDone(:final step, :final skipped):
        _steps[step] = _steps[step]!.copyWith(
            status: skipped ? BootstrapStepStatus.skipped : BootstrapStepStatus.done,
            fraction: 1,
            message: skipped ? 'Already done' : null);
      case EngineBootstrapPrerequisites(:final prerequisites):
        _prerequisites = prerequisites;
      case EngineBootstrapCompleted(:final checkout):
        _checkout = checkout;
        _append('Engine ready: ${checkout.dir}');
      case EngineBootstrapFailed(:final error):
        _error = error;
        _steps[error.step] = _steps[error.step]!.copyWith(status: BootstrapStepStatus.failed, message: error.message);
        _append('Failed: ${error.message}');
    }
    _notify();
  }

  void _append(String line) {
    _log.add(line);
    if (_log.length > maxLogLines) _log.removeRange(0, _log.length - maxLogLines);
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
