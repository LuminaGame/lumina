import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:lumina/lumina.dart' show EngineLoggerService;
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
      // which must report the old marker before writing its own.
      final next = CrashReporter(dataDir: dataDir, logTailLines: 5);
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
      final another = CrashReporter(dataDir: dataDir);
      addTearDown(another.dispose);
      expect(await another.detectPreviousCrash(), isNull, reason: 'a clean close is not a crash');
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
  });

  group('CrashReportView', () {
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
  });
}
