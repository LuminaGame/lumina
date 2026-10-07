import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:http/io_client.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show EngineLoggerService;
import 'package:lumina_editor_api/lumina_editor_api.dart' show LuminaPluginCrashReporter;
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/services/crash_report.dart';
import 'package:lumina_ui/ui/core/services/crash_reporter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/crash_report_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The test binding answers every `HttpClient()` with a canned 400; this
/// hands the reporter a real one, so the request reaches the local server.
class _RealHttpOverrides extends HttpOverrides {}

IOClient realHttpClient() => IOClient(HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttpOverrides()));

/// A real HTTP server standing in for the marketplace's crash report
/// endpoint: records every body it receives and answers with a receipt.
class _ReceivingServer {
  _ReceivingServer._(this.server);

  final HttpServer server;
  final List<Map<String, Object?>> received = [];
  int status = 201;

  Uri get url => Uri.parse('http://127.0.0.1:${server.port}/');

  /// Started outside any test's fake time (its idle timer would otherwise
  /// count as a pending timer); closed after the suite.
  static Future<_ReceivingServer> start() async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = _ReceivingServer._(http);
    http.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      if (request.method == 'POST' && request.uri.path == '/api/v1/crash-reports') {
        s.received.add((jsonDecode(body) as Map).cast<String, Object?>());
        request.response
          ..statusCode = s.status
          ..headers.contentType = ContentType.json
          ..write(s.status == 201
              ? jsonEncode({'id': 'srv-${s.received.length}', 'receivedAt': DateTime.now().toUtc().toIso8601String()})
              : jsonEncode({'error': {'code': 'validation_failed', 'message': 'refused by the test server'}}));
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    return s;
  }
}

void main() {
  late Directory dataDir;
  late _ReceivingServer server;

  setUpAll(() async {
    server = await _ReceivingServer.start();
  });

  tearDownAll(() => server.server.close(force: true));

  setUp(() {
    dataDir = Directory.systemTemp.createTempSync('lumina_crash_');
    server.received.clear();
    server.status = 201;
    addTearDown(() => dataDir.deleteSync(recursive: true));
  });

  CrashReporter reporterFor(Directory dir, {Uri? url}) =>
      CrashReporter(dataDir: dir, serverUrl: url == null ? null : () => url, httpClientFactory: realHttpClient);

  group('CrashReporter', () {
    test('an uncaught error becomes a report file and the pending report; later ones are only filed', () async {
      final reporter = reporterFor(dataDir);
      addTearDown(reporter.dispose);
      EngineLoggerService().log('viewport ready', level: 'info', source: 'Test');
      await reporter.startSession();
      final first = reporter.record(StateError('No element'), StackTrace.current, context: 'building the details panel')!;
      final second = reporter.record(ArgumentError('second'), StackTrace.current)!;
      expect(reporter.pending.value?.id, first.id);
      expect(reporter.filed, hasLength(2));
      expect(first.kind, CrashReportKind.uncaught);
      expect(first.error, contains('No element'));
      expect(first.error, contains('while building the details panel'));
      expect(first.stackTrace, contains('crash_report_test.dart'));
      expect(first.logTail.any((l) => l.contains('viewport ready')), isTrue, reason: 'the log tail is captured');
      expect(first.platform, matches(RegExp(r'^(windows|linux|macos)-(x64|arm64)$')));
      await reporter.flush();
      final file = reporter.fileOf(first);
      expect(file.existsSync(), isTrue);
      final stored = CrashReport.fromJson((jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>());
      expect(stored.error, first.error);
      expect(reporter.fileOf(second).existsSync(), isTrue);
      final listed = await reporter.stored();
      expect(listed.map((r) => r.id), containsAll([first.id, second.id]));
      reporter.dismiss();
      expect(reporter.pending.value, isNull);
    });

    test('a plugin crash is tagged with plugin name and persists across serialization', () async {
      final reporter = reporterFor(dataDir)..install();
      addTearDown(() {
        reporter.uninstall();
        reporter.dispose();
      });

      LuminaPluginCrashReporter.reportCrash(
        StateError('Native memory allocation failure'),
        StackTrace.current,
        plugin: 'lumina_plugin_miniai',
        context: 'generating response tokens',
      );
      await reporter.flush();

      final report = reporter.pending.value;
      expect(report, isNotNull);
      expect(report!.plugin, 'lumina_plugin_miniai');
      expect(report.isPluginCrash, isTrue);
      expect(report.error, contains('Native memory allocation failure'));
      expect(report.error, contains('while generating response tokens'));

      final json = report.toJson();
      expect(json['plugin'], 'lumina_plugin_miniai');

      final restored = CrashReport.fromJson(json);
      expect(restored.plugin, 'lumina_plugin_miniai');
      expect(restored.isPluginCrash, isTrue);

      final text = report.toText();
      expect(text, contains('Plugin: lumina_plugin_miniai'));

      final submission = report.toSubmission();
      expect(submission['plugin'], 'lumina_plugin_miniai');
    });

    test('a session marker left behind becomes a previous-run report with the log tail; a clean close leaves none', () async {
      final crashed = CrashReporter(dataDir: dataDir, logTailLines: 5);
      await crashed.startSession();
      for (var i = 0; i < 8; i++) {
        EngineLoggerService().log('frame $i', level: 'info', source: 'Test');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // The process dies here: no endSession, the marker and the log stay.
      await crashed.detachLog();
      crashed.pending.dispose();
      expect(crashed.sessionMarker.existsSync(), isTrue);

      // The next launch does what editor_entry does: start the session,
      // which must report the old marker before writing its own. (Every
      // reporter here shares this test's pid: the liveness check is told
      // the old one is gone.)
      final next = CrashReporter(dataDir: dataDir, logTailLines: 5, isProcessAlive: (_) async => false);
      addTearDown(next.dispose);
      final report = await next.startSession();
      expect(report, isNotNull, reason: 'the old marker is reported, not hidden by the new one');
      expect(report!.kind, CrashReportKind.previousRun);
      expect(report.error, contains('ended without closing'));
      expect(report.logTail, hasLength(5), reason: 'only the tail of the log file');
      expect(report.logTail.last, contains('frame 7'));
      expect(next.pending.value?.id, report.id);
      expect(next.sessionMarker.existsSync(), isTrue, reason: 'the new session has its own marker now');
      expect(await next.detectPreviousCrash(), isNull, reason: 'its own marker is not a crash');

      await next.endSession();
      expect(next.sessionMarker.existsSync(), isFalse);
      final another = CrashReporter(dataDir: dataDir, isProcessAlive: (_) async => false);
      addTearDown(another.dispose);
      expect(await another.detectPreviousCrash(), isNull, reason: 'a clean close is not a crash');
    });

    test('the launcher handing off and the project editor it starts keep separate markers and logs', () async {
      // The launcher (pid 1000) is still running its exit hooks while the
      // project editor (pid 2000) starts.
      final launcher = CrashReporter(dataDir: dataDir, pid: 1000, isProcessAlive: (_) async => false);
      await launcher.startSession();
      EngineLoggerService().log('launcher line', level: 'info', source: 'Test');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final running = {1000};
      final editor = CrashReporter(dataDir: dataDir, pid: 2000, logTailLines: 5, isProcessAlive: (pid) async => running.contains(pid));
      expect(await editor.startSession(), isNull, reason: 'the launcher is alive: its marker is not a crash');
      expect(launcher.sessionMarker.existsSync(), isTrue, reason: 'and it is left where it is');
      expect(editor.sessionMarker.path, isNot(launcher.sessionMarker.path));
      expect(editor.logFile.path, isNot(launcher.logFile.path));
      EngineLoggerService().log('editor line', level: 'info', source: 'Test');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // The launcher's clean exit removes only its own marker.
      await launcher.endSession();
      launcher.pending.dispose();
      expect(launcher.sessionMarker.existsSync(), isFalse);
      expect(editor.sessionMarker.existsSync(), isTrue, reason: 'the editor keeps its marker: a crash now is still reported');

      // The editor dies; the next launcher reports it with the editor's log.
      await editor.detachLog();
      editor.pending.dispose();
      running.clear();
      final next = CrashReporter(dataDir: dataDir, pid: 3000, logTailLines: 5, isProcessAlive: (pid) async => running.contains(pid));
      addTearDown(next.dispose);
      final report = await next.startSession();
      expect(report?.kind, CrashReportKind.previousRun);
      expect(report!.logTail.join('\n'), contains('editor line'));
      expect(report.logTail.join('\n'), isNot(contains('launcher line')), reason: 'the dead session\'s own log, not the launcher\'s');
      expect(editor.sessionMarker.existsSync(), isFalse);
    });

    test('old per-process logs are pruned, never one a marker still points at', () async {
      final logs = Directory(p.join(dataDir.path, 'logs'))..createSync(recursive: true);
      for (var i = 0; i < 14; i++) {
        final f = File(p.join(logs.path, 'editor-$i.log'))..writeAsStringSync('log $i\n');
        f.setLastModifiedSync(DateTime(2026, 1, 1 + i));
      }
      // A session that died and is reported now; its log must survive the
      // pruning that runs in the same start.
      final dead = CrashReporter(dataDir: dataDir, pid: 3, isProcessAlive: (_) async => false);
      await dead.startSession();
      await dead.detachLog();
      dead.pending.dispose();
      final next = CrashReporter(dataDir: dataDir, pid: 99, keptLogs: 4, isProcessAlive: (_) async => false);
      addTearDown(next.dispose);
      final report = await next.startSession();
      expect(report, isNotNull);
      final left = logs.listSync().map((e) => p.basename(e.path)).toSet();
      expect(left, contains('editor-99.log'));
      expect(left.where((n) => RegExp(r'^editor-\d+\.log$').hasMatch(n) && n != 'editor-99.log').length, lessThanOrEqualTo(5),
          reason: 'the four newest plus the just-reported session\'s log');
      expect(left, contains('editor-13.log'));
      expect(left, isNot(contains('editor-0.log')));
    });

    test('a restart or hand-off is a clean close: the exit hook removes the marker', () async {
      final reporter = reporterFor(dataDir);
      addTearDown(reporter.dispose);
      await reporter.startSession();
      expect(reporter.sessionMarker.existsSync(), isTrue);
      final original = EditorHandOff.instance;
      final exits = <int>[];
      EditorHandOff.instance = EditorHandOff(startDetached: (exe, args) async {}, exitApp: exits.add);
      EditorHandOff.beforeExit.add(reporter.endSession);
      addTearDown(() {
        EditorHandOff.beforeExit.remove(reporter.endSession);
        EditorHandOff.instance = original;
      });
      await EditorHandOff.instance.restartThroughLauncher('/some/project', rebuild: true, launcher: 'lumina_ui');
      expect(exits, [0]);
      expect(reporter.sessionMarker.existsSync(), isFalse, reason: 'the next launch must not call this a crash');
      final next = reporterFor(dataDir);
      addTearDown(next.dispose);
      expect(await next.startSession(), isNull);
    });

    test('a running session does not report its own marker', () async {
      final reporter = CrashReporter(dataDir: dataDir);
      addTearDown(reporter.dispose);
      await reporter.startSession();
      expect(await reporter.detectPreviousCrash(), isNull);
      expect(reporter.sessionMarker.existsSync(), isTrue);
    });

    test('send posts the submission to the server and marks the report sent', () async {
      final reporter = reporterFor(dataDir, url: server.url);
      addTearDown(reporter.dispose);
      final report = reporter.record(Exception('boom'), StackTrace.current)!;
      await reporter.flush();
      final receipt = await reporter.send(report, description: 'Dragged a node', email: 'me@example.test', includeLog: false);
      expect(receipt.id, 'srv-1');
      expect(server.received, hasLength(1));
      final body = server.received.single;
      expect(body['error'], 'Exception: boom');
      expect(body['kind'], 'uncaught');
      expect(body['description'], 'Dragged a node');
      expect(body['email'], 'me@example.test');
      expect(body.containsKey('logTail'), isFalse, reason: 'the log stays home when unticked');
      expect(body['reportId'], report.id);
      expect(reporter.pending.value?.sentId, 'srv-1');
      final onDisk = CrashReport.fromJson((jsonDecode(reporter.fileOf(report).readAsStringSync()) as Map).cast<String, Object?>());
      expect(onDisk.sentId, 'srv-1');
    });
    test('a plugin process death is a plugin_crash report with its exit code and log; the session marker stays', () async {
      final reporter = reporterFor(dataDir, url: server.url);
      addTearDown(reporter.dispose);
      await reporter.startSession();
      final markerBefore = reporter.sessionMarker.readAsStringSync();
      final report = reporter.recordPluginCrash(
        plugin: 'kimodo',
        reason: 'exited with code -1073741819',
        exitCode: -1073741819,
        logTail: const ['[stdout] loading model', '[stderr] access violation'],
      );
      await reporter.flush();
      expect(report.kind, CrashReportKind.pluginCrash);
      expect(report.kind.wire, 'plugin_crash');
      expect(report.plugin, 'kimodo');
      expect(report.exitCode, -1073741819);
      expect(report.logTail, ['[stdout] loading model', '[stderr] access violation']);
      expect(report.error, contains('kimodo'));
      expect(reporter.pending.value?.id, report.id);
      expect(reporter.sessionMarker.readAsStringSync(), markerBefore, reason: 'the editor did not crash');

      final restored = CrashReport.fromJson((jsonDecode(reporter.fileOf(report).readAsStringSync()) as Map).cast<String, Object?>());
      expect(restored.kind, CrashReportKind.pluginCrash);
      expect(restored.exitCode, -1073741819);
      expect(restored.plugin, 'kimodo');
      expect(report.toText(), contains('Kind: plugin process ended unexpectedly'));
      expect(report.toText(), contains('Exit code: -1073741819'));
      final submission = report.toSubmission();
      expect(submission['kind'], 'plugin_crash');
      expect(submission['exitCode'], -1073741819);
      expect(submission['logTail'], report.logTail);
    });
  });

  group('CrashReportView', () {
    testWidgets('a plugin process report says the editor is unaffected and shows the exit code', (tester) async {
      final reporter = reporterFor(dataDir, url: server.url);
      addTearDown(reporter.dispose);
      late final CrashReport report;
      await tester.runAsync(() async {
        report = reporter.recordPluginCrash(plugin: 'fake_plugin', reason: 'exited with code 3', exitCode: 3, logTail: const ['[stderr] bye']);
        await reporter.flush();
      });
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(child: Center(child: CrashReportView(report: report, reporter: reporter, onClose: () {}))),
        ),
      );
      await tester.pump();
      expect(find.text('A PLUGIN PROCESS STOPPED'), findsOneWidget);
      expect(find.textContaining('ended with exit code 3'), findsOneWidget);
      expect(find.text('Plugin: fake_plugin'), findsOneWidget);
    });

    testWidgets('shows the error, sends what the user typed and offers Continue afterwards', (tester) async {
      final reporter = reporterFor(dataDir, url: server.url);
      addTearDown(reporter.dispose);
      // Real file and socket work belongs in runAsync: started under the
      // test's fake time it would never complete.
      late final CrashReport report;
      await tester.runAsync(() async {
        report = reporter.record(StateError('Bad state: material graph has no output node'), StackTrace.current)!;
        await reporter.flush();
      });
      var closed = 0;
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: Center(child: CrashReportView(report: report, reporter: reporter, onClose: () => closed++)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('LUMINA STUDIO RAN INTO A PROBLEM'), findsOneWidget);
      expect(find.textContaining('material graph has no output node'), findsOneWidget);
      expect(find.byKey(const ValueKey('crash_send')), findsOneWidget);
      expect(server.received, isEmpty, reason: 'nothing leaves before Send');

      await tester.enterText(find.byKey(const ValueKey('crash_description')), 'Deleted the output node, then compiled.');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('crash_toggle_details')));
      await tester.pump();
      final details = tester.widget<SelectableText>(find.byKey(const ValueKey('crash_details_text')));
      expect(details.data, contains('Deleted the output node, then compiled.'));
      expect(details.data, contains('Stack trace:'));

      // A real round trip to the local server, outside the test's fake time.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('crash_send')));
        await tester.pump();
        for (var i = 0; i < 100 && server.received.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(server.received, hasLength(1));
      expect(server.received.single['description'], 'Deleted the output node, then compiled.');
      expect(server.received.single['logTail'], isA<List>(), reason: 'the log is included by default');
      expect(find.byKey(const ValueKey('crash_sent')), findsOneWidget);
      expect(find.byKey(const ValueKey('crash_send')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('crash_continue')));
      expect(closed, 1);
    });

    testWidgets('a refused send keeps the report, says where it is, and Copy puts the text on the clipboard', (tester) async {
      server.status = 422;
      final reporter = reporterFor(dataDir, url: server.url);
      addTearDown(reporter.dispose);
      late final CrashReport report;
      await tester.runAsync(() async {
        report = reporter.record(Exception('refused'), StackTrace.current)!;
        await reporter.flush();
      });
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(child: Center(child: CrashReportView(report: report, reporter: reporter, onClose: () {}))),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('crash_send')));
        await tester.pump();
        for (var i = 0; i < 100 && server.received.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('crash_send_error')), findsOneWidget);
      expect(find.textContaining(reporter.fileOf(report).path), findsOneWidget);
      expect(find.byKey(const ValueKey('crash_send')), findsOneWidget, reason: 'can try again');
      await tester.tap(find.byKey(const ValueKey('crash_copy')));
      await tester.pump();
      expect(clipboard, contains('Exception: refused'));
      expect(clipboard, contains('Lumina Studio crash report ${report.id}'));
    });

    testWidgets('the overlay covers the app while a report is pending and goes with Dismiss', (tester) async {
      final reporter = reporterFor(dataDir);
      addTearDown(reporter.dispose);
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: CrashReportOverlay(reporter: reporter, child: const Scaffold(child: Center(child: Text('editor')))),
        ),
      );
      await tester.pump();
      expect(find.byType(CrashReportView), findsNothing);
      await tester.runAsync(() async {
        reporter.record(Exception('late'), StackTrace.current);
        await reporter.flush();
      });
      await tester.pump();
      expect(find.byType(CrashReportView), findsOneWidget);
      expect(find.text('editor'), findsOneWidget, reason: 'the editor stays underneath');
      await tester.tap(find.byKey(const ValueKey('crash_dismiss')));
      await tester.pump();
      expect(find.byType(CrashReportView), findsNothing);
      expect(reporter.fileOf(reporter.filed.single).existsSync(), isTrue, reason: 'dismissing keeps the file');
    });

    testWidgets('shows plugin badge and plugin header when isPluginCrash is true', (tester) async {
      final reporter = reporterFor(dataDir);
      addTearDown(reporter.dispose);
      late final CrashReport report;
      await tester.runAsync(() async {
        report = reporter.record(
          Exception('FFI library crashed'),
          StackTrace.current,
          plugin: 'lumina_plugin_pcg',
        )!;
        await reporter.flush();
      });

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: Center(
              child: CrashReportView(
                report: report,
                reporter: reporter,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('LUMINA PLUGIN ENCOUNTERED AN ERROR'), findsOneWidget);
      expect(find.byKey(const ValueKey('crash_plugin_badge')), findsOneWidget);
      expect(find.text('Plugin: lumina_plugin_pcg'), findsOneWidget);
    });
  });
}
