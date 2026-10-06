import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show ErrorCallback;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lumina/lumina.dart'
    show EditorHostInputs, EngineLogEntry, EngineLoggerService, LuminaDataDir, LuminaGraphicsDevices, LuminaRelease, LuminaRenderBackendInfo;
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';
import 'package:path/path.dart' as p;

import 'crash_report.dart';

/// Catches what nobody else caught and turns it into a [CrashReport] for the
/// crash report screen: [install] hooks Flutter's and the platform
/// dispatcher's error handlers; [record] files a report under
/// `<data dir>/crashes/` and publishes it on [pending] (the first one of a
/// session; later ones are only filed). [startSession] writes a session
/// marker and streams the engine log to `<data dir>/logs/editor.log`;
/// [endSession] removes the marker on a clean close, so a marker still there
/// at the next launch means the process died: [detectPreviousCrash] turns it
/// into a report with the log's tail. [send] posts a report to the
/// marketplace server's `POST /api/v1/crash-reports`; nothing is ever sent
/// without the user pressing Send.
class CrashReporter {
  CrashReporter({
    Directory? dataDir,
    Uri Function()? serverUrl,
    http.Client Function()? httpClientFactory,
    DateTime Function()? clock,
    this.logTailLines = 300,
  })  : _dataDir = dataDir,
        _serverUrl = serverUrl,
        _httpClientFactory = httpClientFactory,
        _clock = clock ?? DateTime.now,
        sessionId = _newSessionId();

  // ignore_for_file: prefer_initializing_formals

  static CrashReporter? _instance;

  /// The reporter [install] made current (null before).
  static CrashReporter? get instance => _instance;

  final Directory? _dataDir;
  final Uri Function()? _serverUrl;
  final http.Client Function()? _httpClientFactory;
  final DateTime Function() _clock;

  /// How many log lines a report carries (and the log file keeps when it is
  /// trimmed at start-up).
  final int logTailLines;

  /// Random per process: the session marker names it, so a marker left by
  /// another process is recognised as such.
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
  File get logFile => File(p.join(dataDir.path, 'logs', 'editor.log'));
  File get sessionMarker => File(p.join(crashesDir.path, 'session.json'));

  /// The marketplace server the report goes to (its `/api/v1/crash-reports`).
  Uri get serverUrl => (_serverUrl ?? () => Uri.parse('http://127.0.0.1:8787'))();

  /// Makes this the process's reporter: uncaught Flutter framework errors and
  /// uncaught asynchronous errors become reports. The previous handlers still
  /// run (Flutter's prints the red box).
  void install() {
    _instance = this;
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
    FlutterError.onError = _previousFlutterHandler;
    PlatformDispatcher.instance.onError = _previousPlatformHandler;
  }

  /// Writes the session marker and starts streaming the engine log to
  /// [logFile] (trimmed to the last [logTailLines] lines first).
  Future<void> startSession() async {
    await crashesDir.create(recursive: true);
    await logFile.parent.create(recursive: true);
    await _trimLog();
    await sessionMarker.writeAsString(jsonEncode({
      'sessionId': sessionId,
      'pid': pid,
      'startedAt': _clock().toUtc().toIso8601String(),
      'release': LuminaRelease.version,
      'commit': LuminaRelease.commit,
    }), flush: true);
    _logSink ??= logFile.openWrite(mode: FileMode.append);
    _logSubscription ??= EngineLoggerService().logStream.listen(_onLog);
    for (final e in EngineLoggerService().logs) {
      _ring.add(_format(e));
    }
    _trimRing();
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

  /// A marker left by another process means that session never closed:
  /// files a previous-run report with the log file's tail and publishes it
  /// (unless a report is already pending). Null when the last session
  /// closed cleanly.
  Future<CrashReport?> detectPreviousCrash() async {
    if (!await sessionMarker.exists()) return null;
    Map<String, Object?> marker;
    try {
      marker = (jsonDecode(await sessionMarker.readAsString()) as Map).cast<String, Object?>();
    } on FormatException {
      marker = const {};
    }
    if (marker['sessionId'] == sessionId) return null;
    await sessionMarker.delete();
    final tail = await _logFileTail();
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
    return report;
  }

  /// Files [error] as a report and shows it when nothing else is pending.
  CrashReport? record(Object error, StackTrace? stack, {String? context}) {
    if (_handling) return null;
    _handling = true;
    try {
      final text = context == null || context.isEmpty ? error.toString() : '$error\n(while $context)';
      final report = _build(kind: CrashReportKind.uncaught, error: text, stackTrace: stack?.toString() ?? '', logTail: List.of(_ring));
      filed.add(report);
      late final Future<void> write;
      write = _file(report).catchError((Object e) => debugPrint('[CrashReporter] could not write ${report.id}: $e')).whenComplete(() => _writes.remove(write));
      _writes.add(write);
      EngineLoggerService().log('Uncaught error filed as crash report ${report.id}: ${report.headline}', level: 'error', source: 'CrashReporter');
      pending.value ??= report;
      return report;
    } finally {
      _handling = false;
    }
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
      if (e is! File || !e.path.endsWith('.json') || p.basename(e.path) == 'session.json') continue;
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

  CrashReport _build({required CrashReportKind kind, required String error, required String stackTrace, required List<String> logTail}) {
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
      logTail: logTail,
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

  Future<void> _trimLog() async {
    if (!await logFile.exists()) return;
    final lines = await _logFileTail();
    await logFile.writeAsString(lines.isEmpty ? '' : '${lines.join('\n')}\n', flush: true);
  }

  Future<List<String>> _logFileTail() async {
    if (!await logFile.exists()) return const [];
    final lines = const LineSplitter().convert(await logFile.readAsString());
    return lines.length > logTailLines ? lines.sublist(lines.length - logTailLines) : lines;
  }

  static String _newSessionId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}
