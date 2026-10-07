import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:io' as io show pid;
import 'dart:math';
import 'dart:ui' show ErrorCallback;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lumina/lumina.dart'
    show EditorHostInputs, EngineLogEntry, EngineLoggerService, LuminaDataDir, LuminaGraphicsDevices, LuminaRelease, LuminaRenderBackendInfo;
import 'package:lumina_editor_api/lumina_editor_api.dart' show LuminaPluginCrashReporter;
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';
import 'package:path/path.dart' as p;

import 'package:lumina_ui/ui/core/services/crash_report.dart';

/// Catches what nobody else caught and turns it into a [CrashReport] for the
/// crash report screen: [install] hooks Flutter's and the platform
/// dispatcher's error handlers; [record] files a report under
/// `<data dir>/crashes/` and publishes it on [pending] (the first one of a
/// session; later ones are only filed). [startSession] writes this process's
/// session marker (`crashes/session-<pid>.json`) and streams the engine log
/// to its own file (`logs/editor-<pid>.log`); [endSession] removes the marker
/// on a clean close, so a marker whose process is gone at the next launch
/// means that process died: [detectPreviousCrash] turns it into a report with
/// that log's tail. Markers and logs are per process because the launcher and
/// the project editor it hands off to overlap for a moment: a shared marker
/// was deleted by the one exiting after the other had written it, and a
/// shared log was trimmed under the other's writes. [send] posts a report to the
/// marketplace server's `POST /api/v1/crash-reports`; nothing is ever sent
/// without the user pressing Send.
class CrashReporter {
  CrashReporter({
    Directory? dataDir,
    Uri Function()? serverUrl,
    http.Client Function()? httpClientFactory,
    DateTime Function()? clock,
    Future<bool> Function(int pid)? isProcessAlive,
    int? pid,
    this.logTailLines = 300,
    this.keptLogs = 10,
  })  : _dataDir = dataDir,
        _serverUrl = serverUrl,
        _httpClientFactory = httpClientFactory,
        _clock = clock ?? DateTime.now,
        _isProcessAlive = isProcessAlive ?? isProcessRunning,
        pid = pid ?? io.pid,
        sessionId = _newSessionId();

  // ignore_for_file: prefer_initializing_formals

  static CrashReporter? _instance;

  /// The reporter [install] made current (null before).
  static CrashReporter? get instance => _instance;

  final Directory? _dataDir;
  final Uri Function()? _serverUrl;
  final http.Client Function()? _httpClientFactory;
  final DateTime Function() _clock;
  final Future<bool> Function(int pid) _isProcessAlive;

  /// How many log lines a report carries.
  final int logTailLines;

  /// How many per-process log files `logs/` keeps (the newest; a log a
  /// marker still points at is never pruned).
  final int keptLogs;

  /// The process this session belongs to: names its marker and its log.
  final int pid;

  /// Random per session: the marker names it, so a marker left by another
  /// session (another process, or this process before a hot restart) is
  /// recognised as such.
  final String sessionId;

  /// The report the screen shows; null when there is none.
  final ValueNotifier<CrashReport?> pending = ValueNotifier<CrashReport?>(null);

  /// Reports filed this session (the shown one first).
  final List<CrashReport> filed = [];

  /// The name of the open project, for the report (set by the editor).
  String projectName = '';

  final List<String> _ring = [];
  StreamSubscription<EngineLogEntry>? _logSubscription;
  IOSink? _logSink;
  bool _handling = false;
  int _counter = 0;
  final Set<Future<void>> _writes = {};
  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;

  Directory get dataDir => _dataDir ?? LuminaDataDir.resolve();
  Directory get crashesDir => Directory(p.join(dataDir.path, 'crashes'));
  Directory get logsDir => Directory(p.join(dataDir.path, 'logs'));

  /// This process's log: `logs/editor-<pid>.log`.
  File get logFile => File(p.join(logsDir.path, 'editor-$pid.log'));

  /// This process's marker: `crashes/session-<pid>.json`.
  File get sessionMarker => File(p.join(crashesDir.path, 'session-$pid.json'));

  /// The single marker and log of editors before markers were per process.
  static const String legacyMarkerName = 'session.json';
  static const String legacyLogName = 'editor.log';

  static bool _isMarkerName(String name) => name == legacyMarkerName || (name.startsWith('session-') && name.endsWith('.json'));

  /// Whether the process [pid] is running (this process: yes). Windows asks
  /// `tasklist`, Linux looks in `/proc`, elsewhere `kill -0`. When that
  /// cannot be told, the process counts as gone: a report too many beats a
  /// crash never reported.
  static Future<bool> isProcessRunning(int pid) async {
    if (pid == io.pid) return true;
    try {
      if (Platform.isWindows) {
        final r = await Process.run('tasklist', ['/FI', 'PID eq $pid', '/NH', '/FO', 'CSV']);
        return (r.stdout as String).contains('"$pid"');
      }
      if (Platform.isLinux) return await Directory('/proc/$pid').exists();
      final r = await Process.run('kill', ['-0', '$pid']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// The marketplace server the report goes to (its `/api/v1/crash-reports`).
  Uri get serverUrl => (_serverUrl ?? () => Uri.parse('http://127.0.0.1:8787'))();

  /// Makes this the process's reporter: uncaught Flutter framework errors and
  /// uncaught asynchronous errors become reports. The previous handlers still
  /// run (Flutter's prints the red box).
  void install() {
    _instance = this;
    LuminaPluginCrashReporter.setHandler((error, stack, {required plugin, context}) {
      record(error, stack, context: context, plugin: plugin);
    });
    _previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _previousFlutterHandler?.call(details);
      record(details.exception, details.stack, context: details.context?.toDescription());
    };
    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack);
      return true;
    };
  }

  /// Undoes [install] (tests).
  void uninstall() {
    if (_instance == this) _instance = null;
    LuminaPluginCrashReporter.setHandler(null);
    FlutterError.onError = _previousFlutterHandler;
    PlatformDispatcher.instance.onError = _previousPlatformHandler;
  }

  /// Starts this session: first looks for markers of sessions that died
  /// ([detectPreviousCrash]; the first report is returned), prunes old
  /// per-process logs, then writes this session's marker and streams the
  /// engine log to [logFile]. The order matters: the new marker would hide
  /// an old one of the same process.
  Future<CrashReport?> startSession() async {
    await crashesDir.create(recursive: true);
    await logsDir.create(recursive: true);
    final previous = await detectPreviousCrash();
    await _pruneLogs();
    await sessionMarker.writeAsString(jsonEncode({
      'sessionId': sessionId,
      'pid': pid,
      'startedAt': _clock().toUtc().toIso8601String(),
      'release': LuminaRelease.version,
      'commit': LuminaRelease.commit,
      'log': logFile.path,
    }), flush: true);
    _logSink ??= logFile.openWrite(mode: FileMode.writeOnly);
    _logSubscription ??= EngineLoggerService().logStream.listen(_onLog);
    for (final e in EngineLoggerService().logs) {
      _ring.add(_format(e));
    }
    _trimRing();
    return previous;
  }

  /// The clean close: the marker goes, the log is flushed.
  Future<void> endSession() async {
    await detachLog();
    if (await sessionMarker.exists()) await sessionMarker.delete();
  }

  /// Stops streaming the log and closes the file, leaving the session marker
  /// where it is: what a process that dies leaves behind (tests end a
  /// "crashed" session this way so its files can be removed).
  Future<void> detachLog() async {
    await _logSubscription?.cancel();
    _logSubscription = null;
    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;
  }

  /// Completes when every report file started so far is written.
  Future<void> flush() => Future.wait(_writes.toList());

  /// A marker of another session whose process is gone means that session
  /// never closed: files a previous-run report with that session's log tail
  /// and publishes it (unless a report is already pending). A marker whose
  /// process is still running (the launcher that is handing off to this
  /// editor, or the other way round) is left alone. Null when nothing died.
  Future<CrashReport?> detectPreviousCrash() async {
    if (!await crashesDir.exists()) return null;
    CrashReport? first;
    await for (final e in crashesDir.list()) {
      if (e is! File || !_isMarkerName(p.basename(e.path))) continue;
      Map<String, Object?> marker;
      try {
        marker = (jsonDecode(await e.readAsString()) as Map).cast<String, Object?>();
      } on FormatException {
        marker = const {};
      }
      if (marker['sessionId'] == sessionId) continue;
      final markerPid = marker['pid'];
      if (markerPid is int && await _isProcessAlive(markerPid)) continue;
      await e.delete();
      final logPath = marker['log'];
      final log = logPath is String && logPath.isNotEmpty ? File(logPath) : File(p.join(logsDir.path, legacyLogName));
      final tail = await _logFileTail(log);
      final started = marker['startedAt'] as String? ?? 'an unknown time';
      final release = marker['release'] as String? ?? '';
      final report = _build(
        kind: CrashReportKind.previousRun,
        error: 'Lumina Studio ended without closing: the session started at $started'
            '${release.isNotEmpty ? ' (release $release)' : ''} left no clean exit, so the process crashed or was killed.',
        stackTrace: '',
        logTail: tail,
      );
      await _file(report);
      filed.add(report);
      pending.value ??= report;
      first ??= report;
    }
    return first;
  }

  /// Files [error] as a report and shows it when nothing else is pending.
  CrashReport? record(Object error, StackTrace? stack, {String? context, String? plugin}) {
    if (_handling) return null;
    _handling = true;
    try {
      final text = context == null || context.isEmpty ? error.toString() : '$error\n(while $context)';
      final report = _build(
        kind: CrashReportKind.uncaught,
        error: text,
        stackTrace: stack?.toString() ?? '',
        logTail: List.of(_ring),
        plugin: plugin ?? '',
      );
      filed.add(report);
      late final Future<void> write;
      write = _file(report).catchError((Object e) => debugPrint('[CrashReporter] could not write ${report.id}: $e')).whenComplete(() => _writes.remove(write));
      _writes.add(write);
      final pluginTag = (plugin != null && plugin.isNotEmpty) ? ' (plugin: $plugin)' : '';
      EngineLoggerService().log(
        'Uncaught error$pluginTag filed as crash report ${report.id}: ${report.headline}',
        level: 'error',
        source: (plugin != null && plugin.isNotEmpty) ? 'Plugin:$plugin' : 'CrashReporter',
      );
      pending.value ??= report;
      return report;
    } finally {
      _handling = false;
    }
  }

  /// Files the death of an isolated plugin's process: a
  /// [CrashReportKind.pluginCrash] report naming [plugin], its [exitCode]
  /// and the process's own [logTail], shown when nothing else is pending.
  /// The editor's session marker is not touched: the editor did not crash.
  CrashReport recordPluginCrash({required String plugin, required String reason, int? exitCode, List<String> logTail = const []}) {
    final tail = logTail.length > logTailLines ? logTail.sublist(logTail.length - logTailLines) : List.of(logTail);
    final report = _build(
      kind: CrashReportKind.pluginCrash,
      error: 'The process of plugin "$plugin" $reason. The editor kept running.',
      stackTrace: '',
      logTail: tail,
      plugin: plugin,
      exitCode: exitCode,
    );
    filed.add(report);
    late final Future<void> write;
    write = _file(report).catchError((Object e) => debugPrint('[CrashReporter] could not write ${report.id}: $e')).whenComplete(() => _writes.remove(write));
    _writes.add(write);
    EngineLoggerService().log('Plugin $plugin process $reason: filed crash report ${report.id}',
        level: 'error', source: 'Plugin:$plugin');
    pending.value ??= report;
    return report;
  }

  /// Sends [report] with what the user typed and marks it sent.
  Future<CrashReportReceipt> send(CrashReport report, {String description = '', String email = '', bool includeLog = true}) async {
    final client = MarketplaceClient(baseUrl: serverUrl, httpClient: _httpClientFactory?.call(), keepRefreshToken: false);
    try {
      final receipt = await client.submitCrashReport(report.toSubmission(description: description, email: email, includeLog: includeLog));
      final sent = report.copyWith(sentId: receipt.id);
      final i = filed.indexWhere((r) => r.id == report.id);
      if (i >= 0) filed[i] = sent;
      if (pending.value?.id == report.id) pending.value = sent;
      await _file(sent);
      return receipt;
    } finally {
      client.close();
    }
  }

  /// Hides the screen; the report stays on disk.
  void dismiss() => pending.value = null;

  /// The file of [report] under [crashesDir].
  File fileOf(CrashReport report) => File(p.join(crashesDir.path, '${report.id}.json'));

  /// Every report on disk, newest first.
  Future<List<CrashReport>> stored() async {
    if (!await crashesDir.exists()) return const [];
    final reports = <CrashReport>[];
    await for (final e in crashesDir.list()) {
      if (e is! File || !e.path.endsWith('.json') || _isMarkerName(p.basename(e.path))) continue;
      try {
        reports.add(CrashReport.fromJson((jsonDecode(await e.readAsString()) as Map).cast<String, Object?>()));
      } on FormatException {
        // not a report
      }
    }
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  Future<void> dispose() async {
    await flush();
    await endSession();
    pending.dispose();
  }

  CrashReport _build({
    required CrashReportKind kind,
    required String error,
    required String stackTrace,
    required List<String> logTail,
    String plugin = '',
    int? exitCode,
  }) {
    final now = _clock();
    String gpu;
    try {
      gpu = LuminaGraphicsDevices.inUse.value ?? '';
    } catch (_) {
      gpu = '';
    }
    String filament;
    try {
      filament = LuminaRenderBackendInfo.filamentVersion;
    } catch (_) {
      filament = '';
    }
    return CrashReport(
      id: '${now.millisecondsSinceEpoch}-${(++_counter).toString().padLeft(2, '0')}',
      kind: kind,
      createdAt: now,
      error: error,
      stackTrace: stackTrace,
      release: LuminaRelease.version,
      commit: LuminaRelease.commit,
      editor: 'Lumina Studio${LuminaRelease.version.isEmpty ? ' (dev build)' : ''}',
      platform: EditorHostInputs.currentPlatform(),
      osVersion: Platform.operatingSystemVersion,
      gpu: gpu,
      filament: filament,
      project: projectName,
      plugin: plugin,
      logTail: logTail,
      exitCode: exitCode,
    );
  }

  Future<void> _file(CrashReport report) async {
    await crashesDir.create(recursive: true);
    await fileOf(report).writeAsString(report.toJsonString(), flush: true);
  }

  void _onLog(EngineLogEntry e) {
    final line = _format(e);
    _ring.add(line);
    _trimRing();
    _logSink?.writeln(line);
  }

  void _trimRing() {
    if (_ring.length > logTailLines) _ring.removeRange(0, _ring.length - logTailLines);
  }

  static String _format(EngineLogEntry e) => '[${e.timestamp}] [${e.level.toUpperCase()}] [${e.source}] ${e.message}';

  /// Keeps the newest [keptLogs] per-process logs, never one a marker still
  /// points at (a running sibling, or a death not yet reported) and never
  /// this process's own.
  Future<void> _pruneLogs() async {
    if (!await logsDir.exists()) return;
    final referenced = <String>{};
    if (await crashesDir.exists()) {
      await for (final e in crashesDir.list()) {
        if (e is! File || !_isMarkerName(p.basename(e.path))) continue;
        try {
          final marker = (jsonDecode(await e.readAsString()) as Map).cast<String, Object?>();
          if (marker['log'] is String) referenced.add(p.normalize(marker['log'] as String));
        } on FormatException {
          // not a marker
        }
      }
    }
    final logs = <File>[];
    await for (final e in logsDir.list()) {
      if (e is! File) continue;
      final name = p.basename(e.path);
      if (!name.startsWith('editor-') || !name.endsWith('.log')) continue;
      if (p.normalize(e.path) == p.normalize(logFile.path) || referenced.contains(p.normalize(e.path))) continue;
      logs.add(e);
    }
    if (logs.length <= keptLogs) return;
    final stats = <File, DateTime>{for (final f in logs) f: (await f.stat()).modified};
    logs.sort((a, b) => stats[b]!.compareTo(stats[a]!));
    for (final old in logs.skip(keptLogs)) {
      try {
        await old.delete();
      } on FileSystemException {
        // in use elsewhere; next time
      }
    }
  }

  Future<List<String>> _logFileTail(File log) async {
    if (!await log.exists()) return const [];
    final lines = const LineSplitter().convert(await log.readAsString()).where((l) => l.isNotEmpty).toList();
    return lines.length > logTailLines ? lines.sublist(lines.length - logTailLines) : lines;
  }

  static String _newSessionId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}
