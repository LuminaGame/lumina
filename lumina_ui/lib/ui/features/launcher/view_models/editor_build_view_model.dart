import 'dart:async';
import 'dart:io';

import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

enum EditorBuildSplashState { running, failed, succeeded, cancelled }

/// Drives [EditorBuildSplash] from a real [EditorBuildJob]: the
/// status line, the progress bar, the log tail and the failure state.
class EditorBuildViewModel extends ChangeNotifier {
  final String projectName;
  final String projectDir;
  final String engineVersion;

  /// Starts (and on Retry restarts) the build.
  final EditorBuildJob Function() startBuild;

  /// Whether the project enables code plugins: a failed build then offers
  /// "Open without plugins", otherwise "Open in this editor".
  final bool hasPlugins;

  EditorBuildViewModel({
    required this.projectName,
    required this.projectDir,
    required this.startBuild,
    this.engineVersion = '0.0.1',
    this.hasPlugins = true,
  });

  static const int logTailLines = 10;

  EditorBuildJob? _job;
  StreamSubscription<EditorBuildProgress>? _sub;
  EditorBuildSplashState _state = EditorBuildSplashState.running;
  EditorBuildPhase _phase = EditorBuildPhase.copyingSource;
  double _fraction = 0;
  String _message = 'Preparing editor…';
  final List<String> _log = [];
  String? _logPath;
  EditorBuildOutcome? _outcome;
  bool _showLog = false;
  bool _disposed = false;

  EditorBuildSplashState get state => _state;
  EditorBuildPhase get phase => _phase;
  double get fraction => _fraction;
  int get percent => (_fraction * 100).floor().clamp(0, 100);
  String? get logPath => _logPath;
  EditorBuildOutcome? get outcome => _outcome;
  bool get showLog => _showLog;
  List<String> get logTail => _log.length <= logTailLines ? List.unmodifiable(_log) : _log.sublist(_log.length - logTailLines);

  /// Every log line kept so far (the latest 400), for the scrollable log.
  List<String> get logLines => List.unmodifiable(_log);

  /// `NN% - <phase message>`, or the failure line.
  String get statusText => switch (_state) {
        EditorBuildSplashState.failed => 'Build failed — see log',
        EditorBuildSplashState.cancelled => 'Build cancelled',
        EditorBuildSplashState.succeeded => '100% - Starting editor',
        EditorBuildSplashState.running => '$percent% - $_message',
      };

  /// Completes with the outcome of the current run.
  Future<EditorBuildOutcome> start() {
    _state = EditorBuildSplashState.running;
    _fraction = 0;
    _message = 'Preparing editor…';
    _log.clear();
    _outcome = null;
    final job = _job = startBuild();
    _sub = job.progress.listen((p) {
      if (_disposed) return;
      if (p.fraction >= _fraction) _fraction = p.fraction; // never goes back
      _phase = p.phase;
      _message = p.message;
      if (p.logLine != null) _log.add(p.logLine!);
      if (_log.length > 400) _log.removeRange(0, _log.length - 400);
      _logPath = job.logPath ?? _logPath;
      notifyListeners();
    });
    return job.result.then((outcome) async {
      await _sub?.cancel();
      _outcome = outcome;
      _logPath = job.logPath ?? _logPath;
      switch (outcome) {
        case EditorBuildSucceeded():
          _fraction = 1;
          _state = EditorBuildSplashState.succeeded;
        case EditorBuildFailed(:final lastLines):
          _state = EditorBuildSplashState.failed;
          _showLog = true;
          if (_log.isEmpty) _log.addAll(lastLines);
        case EditorBuildCancelled():
          _state = EditorBuildSplashState.cancelled;
      }
      if (!_disposed) notifyListeners();
      return outcome;
    });
  }

  void toggleLog() {
    _showLog = !_showLog;
    notifyListeners();
  }

  void cancel() => _job?.cancel();

  /// Opens the full build log with the OS's default handler.
  Future<void> openLogFile() async {
    final path = _logPath;
    if (path == null || !File(path).existsSync()) return;
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', path], mode: ProcessStartMode.detached);
    } else {
      await Process.start(Platform.isMacOS ? 'open' : 'xdg-open', [path], mode: ProcessStartMode.detached);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
